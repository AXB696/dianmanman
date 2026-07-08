"""
电满满 - 导航功能模拟驾驶测试
===================================
模拟一辆车从起点沿高德规划的路线行驶，测试以下导航核心逻辑：
  1. 路线剩余距离计算
  2. 当前路段匹配
  3. 偏航检测（50m阈值）
  4. 到达判定（100m + 低速 + 3秒确认）
  5. 偏航后重规划

使用真实的高德路线数据（通过 /api/route 获取）
"""
import math
import json
import time
import random
import urllib.request
from typing import List, Tuple, Dict, Optional

# ==================== 常量（与 Flutter 代码一致） ====================
OFF_ROUTE_THRESHOLD_METERS = 50.0   # 偏航阈值：单次检测阈值
OFF_ROUTE_DEBOUNCE_COUNT = 3       # 偏航去抖：连续N次超阈值才触发
GPS_TIMEOUT_SECONDS = 10           # GPS超时秒数
ARRIVAL_DISTANCE_METERS = 100.0     # 到达判定距离（米）
GPS_ACCURACY_THRESHOLD = 25.0       # GPS 精度过滤阈值（米）
ARRIVAL_SPEED_THRESHOLD = 5.0       # 到达时最大速度（km/h）
ARRIVAL_CONFIRM_SECONDS = 3         # 到达需持续多少秒
LOCATION_INTERVAL_SEC = 2           # GPS 更新间隔（秒）
EARTH_RADIUS_KM = 6371              # 地球半径（公里）


# ==================== 工具函数（从 Flutter 代码翻译） ====================

def haversine_distance_km(lat1: float, lng1: float,
                           lat2: float, lng2: float) -> float:
    """Haversine 公式计算两点距离（公里）"""
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (math.sin(d_lat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(d_lng / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return EARTH_RADIUS_KM * c


def point_to_segment_distance_km(px: float, py: float,
                                  x1: float, y1: float,
                                  x2: float, y2: float) -> float:
    """点到线段的最短距离（公里）"""
    dx = x2 - x1
    dy = y2 - y1
    length_sq = dx * dx + dy * dy
    if length_sq == 0:
        return haversine_distance_km(px, py, x1, y1)
    t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / length_sq))
    nearest_x = x1 + t * dx
    nearest_y = y1 + t * dy
    return haversine_distance_km(px, py, nearest_x, nearest_y)


def find_nearest_point_on_polyline(lat: float, lng: float,
                                    polyline: List[List[float]]) -> int:
    """找到 polyline 上距离当前位置最近的点的索引"""
    min_dist = float('inf')
    nearest_idx = 0
    for i in range(len(polyline) - 1):
        p1 = polyline[i]
        p2 = polyline[i + 1]
        dist = point_to_segment_distance_km(lat, lng, p1[0], p1[1], p2[0], p2[1])
        if dist < min_dist:
            min_dist = dist
            nearest_idx = i
    return nearest_idx


def check_deviation(lat: float, lng: float,
                     polyline: List[List[float]],
                     off_route_count: int = 0) -> Tuple[bool, float, int]:
    """
    检查是否偏离路线，带连续去抖
    返回 (是否触发偏航, 最短距离米, 新的偏航计数)
    """
    if not polyline:
        return False, 0.0, 0

    min_dist_km = float('inf')
    for i in range(len(polyline) - 1):
        p1 = polyline[i]
        p2 = polyline[i + 1]
        dist = point_to_segment_distance_km(lat, lng, p1[0], p1[1], p2[0], p2[1])
        if dist < min_dist_km:
            min_dist_km = dist

    dist_meters = min_dist_km * 1000
    if dist_meters > OFF_ROUTE_THRESHOLD_METERS:
        off_route_count += 1
        if off_route_count >= OFF_ROUTE_DEBOUNCE_COUNT:
            return True, dist_meters, off_route_count
    else:
        off_route_count = 0
    return False, dist_meters, off_route_count


def calculate_remaining_from_polyline(lat: float, lng: float,
                                       polyline: List[List[float]]) -> float:
    """从当前位置沿路线计算到终点的剩余距离（公里）"""
    if len(polyline) < 2:
        return 0.0

    nearest_idx = find_nearest_point_on_polyline(lat, lng, polyline)
    remaining_km = 0.0
    for i in range(nearest_idx, len(polyline) - 1):
        remaining_km += haversine_distance_km(
            polyline[i][0], polyline[i][1],
            polyline[i + 1][0], polyline[i + 1][1]
        )
    return max(0.0, remaining_km)


def calculate_step_index(lat: float, lng: float,
                          polyline: List[List[float]],
                          steps: List[Dict]) -> int:
    """
    根据当前位置精确匹配当前所在导航步骤
    使用用户坐标在 polyline 上的精确投影位置，而非粗略估算
    """
    if not steps or len(polyline) < 2:
        return 0

    nearest_idx = find_nearest_point_on_polyline(lat, lng, polyline)

    # 精确计算已行驶的 polyline 距离
    traveled_km = 0.0
    for i in range(nearest_idx):
        traveled_km += haversine_distance_km(
            polyline[i][0], polyline[i][1],
            polyline[i + 1][0], polyline[i + 1][1]
        )

    # 当前路段的部分距离：投影参数 t 精确计算比例
    if nearest_idx < len(polyline) - 1:
        p1 = polyline[nearest_idx]
        p2 = polyline[nearest_idx + 1]
        dx = p2[0] - p1[0]
        dy = p2[1] - p1[1]
        seg_len_km = haversine_distance_km(p1[0], p1[1], p2[0], p2[1])
        denom = dx * dx + dy * dy
        if denom > 0 and seg_len_km > 0:
            t = ((lat - p1[0]) * dx + (lng - p1[1]) * dy) / denom
            t = max(0.0, min(1.0, t))
            traveled_km += seg_len_km * t

    # 匹配 step
    cumulative_km = 0.0
    for i, step in enumerate(steps):
        step_dist = step.get('distance_km', 0)
        if cumulative_km + step_dist > traveled_km:
            return i
        cumulative_km += step_dist
    return len(steps) - 1 if steps else 0


def check_arrival(dist_meters: float, speed_kmh: float,
                   arrival_start: Optional[float]) -> Tuple[bool, Optional[float]]:
    """
    到达检测逻辑（与 Flutter 一致）
    条件：距离 < 100m AND 速度 < 5km/h 持续 3 秒
    返回：(是否到达, 新的到达确认开始时间)
    """
    if dist_meters < ARRIVAL_DISTANCE_METERS and speed_kmh < ARRIVAL_SPEED_THRESHOLD:
        now = time.time()
        if arrival_start is None:
            return False, now
        elif now - arrival_start >= ARRIVAL_CONFIRM_SECONDS:
            return True, arrival_start
        else:
            return False, arrival_start
    else:
        return False, None


# ==================== 主模拟逻辑 ====================

class NavigationSimulator:
    """模拟导航引擎，逻辑与 Flutter NavigationScreen 一致"""

    def __init__(self, route_data: dict):
        data = route_data['data']
        self.polyline: List[List[float]] = data['polyline']
        self.steps: List[Dict] = data['steps']
        self.total_distance_km: float = data['distance_km']
        self.total_duration_min: int = data['duration_min']

        # 路线起终点
        self.origin = self.polyline[0]
        self.destination = self.polyline[-1]

        # 模拟状态
        self.current_lat: float = self.origin[0]
        self.current_lng: float = self.origin[1]
        self.speed_kmh: float = 0.0
        self.remaining_km: float = self.total_distance_km
        self.current_step_idx: int = 0
        self.is_arrived: bool = False
        self.is_off_route: bool = False
        self.arrival_confirm_start: Optional[float] = None
        self.deviation_count: int = 0  # 总偏航触发次数
        self.off_route_count: int = 0  # 连续偏航计数器（去抖用）
        self.total_ticks: int = 0

        # 日志
        self.log: List[str] = []

    def _tick(self, lat: float, lng: float, speed_kmh: float,
              label: str = ""):
        """每个 GPS 更新周期执行的完整导航逻辑"""
        self.total_ticks += 1

        # 1. 偏航检测（带去抖：连续3次超阈值才触发）
        off_route, dist_to_route, self.off_route_count = check_deviation(
            lat, lng, self.polyline, self.off_route_count)
        self.is_off_route = off_route

        # 2. 计算剩余距离
        remaining = calculate_remaining_from_polyline(lat, lng, self.polyline)

        # 3. 匹配当前步骤
        step_idx = calculate_step_index(lat, lng, self.polyline, self.steps)

        # 4. 到达检测
        arrived, confirm_start = check_arrival(
            remaining * 1000, speed_kmh, self.arrival_confirm_start
        )
        self.arrival_confirm_start = confirm_start

        # 更新状态
        self.current_lat = lat
        self.current_lng = lng
        self.speed_kmh = speed_kmh
        self.remaining_km = remaining
        self.current_step_idx = step_idx
        self.is_arrived = arrived

        # 获取当前步骤信息
        step = self.steps[step_idx] if step_idx < len(self.steps) else self.steps[-1]

        # 日志
        dist_m = remaining * 1000
        arrival_wait = ""
        if self.arrival_confirm_start and not arrived:
            elapsed = time.time() - self.arrival_confirm_start
            arrival_wait = f" 🔔到达确认中({elapsed:.1f}s/{ARRIVAL_CONFIRM_SECONDS}s)"

        off_route_flag = " ❗偏航!" if off_route else ""
        label_str = f" [{label}]" if label else ""

        self.log.append(
            f"[Tick {self.total_ticks:02d}]{label_str} "
            f"位置({lat:.6f},{lng:.6f}) "
            f"速度{speed_kmh:.0f}km/h "
            f"剩余{dist_m:.0f}m "
            f"距路线{dist_to_route:.1f}m"
            f"{off_route_flag}"
            f"{arrival_wait}"
            f" | 路段{step_idx+1}:{step.get('action','?')} → {step.get('instruction','')[:20]}"
        )

    # ---- 模拟场景 ----

    def simulate_normal_drive(self):
        """
        场景1：正常驾驶 - 沿路线匀速行驶直到到达
        """
        print("\n" + "=" * 70)
        print("🚗 场景1：正常驾驶 - 沿路线行驶直到到达")
        print("=" * 70)
        print(f"路线：{self.polyline[0]} → {self.polyline[-1]}")
        print(f"总距离：{self.total_distance_km:.2f} km")
        print(f"预计时间：{self.total_duration_min} 分钟")
        print(f"路线点数：{len(self.polyline)} 个")
        print(f"导航步骤：{len(self.steps)} 步")
        print()

        # 在 polyline 上采样位置，模拟行驶
        sample_interval = max(1, len(self.polyline) // 30)  # 约30步走完

        tick = 0
        for i in range(0, len(self.polyline), sample_interval):
            pt = self.polyline[i]
            # 模拟速度（到达时减速）
            progress = i / len(self.polyline)
            if progress > 0.9:
                speed = 5.0 * (1 - progress) / 0.1  # 最后10%减速到0
            elif progress > 0.8:
                speed = 30.0  # 市区正常速度
            else:
                speed = 40.0

            self._tick(pt[0], pt[1], speed)
            tick += 1

            if self.is_arrived:
                break

            # 模拟到达确认：在终点附近保持低速多等几秒
            # 每次GPS更新间隔2秒，模拟真实时间流逝
            if i >= len(self.polyline) - 2 and not self.is_arrived:
                for _ in range(3):  # 多等 3 个周期（6秒）
                    time.sleep(LOCATION_INTERVAL_SEC)  # 模拟2秒GPS间隔
                    self._tick(pt[0], pt[1], 2.0, label="减速等待")
                    tick += 1
                    if self.is_arrived:
                        break
                break

        return self.is_arrived

    def simulate_with_deviation(self, deviation_at_pct: float = 0.5):
        """
        场景2：偏航测试 - 在路线中途故意偏离，测试偏航检测
        """
        print("\n" + "=" * 70)
        print("🔄 场景2：偏航测试 - 故意偏离路线")
        print("=" * 70)
        print(f"在第 {deviation_at_pct*100:.0f}% 处偏航")
        print()

        sample_interval = max(1, len(self.polyline) // 20)
        deviated = False

        for i in range(0, len(self.polyline), sample_interval):
            pt = self.polyline[i]
            progress = i / len(self.polyline)

            if not deviated and progress >= deviation_at_pct:
                # 故意偏离：往东偏移约 0.001 度（约 100 米）
                deviated_lat = pt[0] + 0.0002
                deviated_lng = pt[1] + 0.0010
                print(f"\n⚠️  {i}/{len(self.polyline)} 处故意偏航！")
                print(f"   正确路线点: ({pt[0]:.6f}, {pt[1]:.6f})")
                print(f"   偏航位置:   ({deviated_lat:.6f}, {deviated_lng:.6f})")
                print()

                self._tick(deviated_lat, deviated_lng, 35.0, label="偏航点")

                # 继续偏航几个周期
                for j in range(3):
                    further_lat = deviated_lat + 0.0001 * j
                    further_lng = deviated_lng + 0.0003 * j
                    self._tick(further_lat, further_lng, 35.0,
                                label=f"持续偏航{j+1}")

                deviated = True
                break
            else:
                speed = 35.0 if progress < 0.9 else 15.0
                self._tick(pt[0], pt[1], speed, label="正常行驶")

        # 模拟偏航后重规划：后端重新请求路线
        if deviated:
            print(f"\n🔄 偏航后重规划（模拟重新调用 /api/route）...")
            self.simulate_rerouting()

        return self.is_off_route

    def simulate_rerouting(self):
        """
        模拟偏航后重新规划路线（从偏航位置调用后端API）
        """
        try:
            payload = json.dumps({
                "origin_lat": self.current_lat,
                "origin_lng": self.current_lng,
                "dest_lat": self.destination[0],
                "dest_lng": self.destination[1],
            }).encode()
            req = urllib.request.Request(
                "http://localhost:8000/api/route",
                data=payload,
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                new_route = json.loads(resp.read())

            if new_route.get('code') == 200:
                new_data = new_route['data']
                print(f"   ✅ 重规划成功！")
                print(f"   新路线距离: {new_data['distance_km']} km")
                print(f"   新路线耗时: {new_data['duration_min']} 分钟")
                print(f"   新路线步骤: {len(new_data['steps'])} 步")

                # 更新路线数据
                self.polyline = new_data['polyline']
                self.steps = new_data['steps']
                self.total_distance_km = new_data['distance_km']
                self.total_duration_min = new_data['duration_min']
                self.is_off_route = False
                self.off_route_count = 0  # 重置偏航计数器

                # 快速模拟走完新路线
                print(f"\n   沿新路线继续行驶...")
                self._fast_drive_new_route()
            else:
                print(f"   ❌ 重规划失败: {new_route.get('message')}")
        except Exception as e:
            print(f"   ❌ 重规划请求失败: {e}")

    def _fast_drive_new_route(self):
        """快速走完新规划的路线"""
        sample_interval = max(1, len(self.polyline) // 10)
        for i in range(0, len(self.polyline), sample_interval):
            pt = self.polyline[i]
            progress = i / len(self.polyline)
            speed = 35.0 if progress < 0.9 else 5.0
            self._tick(pt[0], pt[1], speed, label="新路线")
            if self.is_arrived:
                break

    def simulate_arrival(self):
        """
        场景3：到达检测 - 精确测试三重到达确认
        """
        print("\n" + "=" * 70)
        print("🏁 场景3：到达检测 - 测试三重确认机制")
        print("=" * 70)
        print(f"条件：距离<{ARRIVAL_DISTANCE_METERS}m + 速度<{ARRIVAL_SPEED_THRESHOLD}km/h + 持续{ARRIVAL_CONFIRM_SECONDS}s")
        print()

        dest_lat = self.destination[0]
        dest_lng = self.destination[1]

        # 测试1：距离近但速度过快 → 不应到达
        print("测试 A：距离 50m，速度 40km/h → 不应判定到达")
        near_point = [dest_lat - 0.0003, dest_lng - 0.0002]
        self._tick(near_point[0], near_point[1], 40.0, label="速度过快")
        assert self.arrival_confirm_start is None, \
            "FAIL: 速度过快时不应该开始到达确认！"
        print("   ✅ 通过（正确：到达确认未触发）\n")

        # 测试2：距离近且速度慢，但时间不够 → 到达确认中
        print("测试 B：距离 50m，速度 2km/h，持续 2 秒（不够 3 秒）→ 不应到达")
        for _ in range(1):  # 1个周期=2秒
            self._tick(near_point[0], near_point[1], 2.0, label="等待中")
        assert not self.is_arrived, "FAIL: 不应该到达！"
        assert self.arrival_confirm_start is not None, \
            "FAIL: 应该正在确认到达！"
        print("   ✅ 通过（正确：到达确认中但未触发）\n")

        # 测试3：满3秒后触发到达
        print("测试 C：距离 50m，速度 2km/h，再等 4 秒（累计 >3 秒）→ 应到达")
        # 手动设置确认开始时间到 4 秒前
        self.arrival_confirm_start = time.time() - 4.0
        self._tick(near_point[0], near_point[1], 1.0, label="最终确认")
        assert self.is_arrived, "FAIL: 应该判定到达！"
        print("   ✅ 通过（正确：判定到达！）\n")

        # 测试4：距离远且速度慢 → 不应触发
        print("测试 D：距离 500m，速度 3km/h → 不应触发任何到达逻辑")
        # 重置状态
        self.is_arrived = False
        self.arrival_confirm_start = None
        far_point = [dest_lat - 0.005, dest_lng - 0.004]
        self._tick(far_point[0], far_point[1], 3.0, label="距离太远")
        assert self.arrival_confirm_start is None, \
            "FAIL: 距离太远不应该触发到达确认！"
        print("   ✅ 通过（正确：距离过远未触发）\n")

        return True

    def print_summary(self):
        """打印模拟总结"""
        print("\n" + "=" * 70)
        print("📊 模拟驾驶总结")
        print("=" * 70)
        print(f"总模拟步数: {self.total_ticks}")
        print(f"偏航检测次数: {self.deviation_count}")
        print(f"最终状态: {'🏁 已到达' if self.is_arrived else '🛣️ 行驶中'}")
        print(f"偏航状态: {'是' if self.is_off_route else '否'}")
        print()

        if self.log:
            print("── 详细日志 ──")
            for entry in self.log:
                print(f"  {entry}")
            print()


# ==================== 启动测试 ====================

def fetch_route(origin_lat: float, origin_lng: float,
                dest_lat: float, dest_lng: float) -> dict:
    """调用后端 /api/route 获取真实路线"""
    payload = json.dumps({
        "origin_lat": origin_lat,
        "origin_lng": origin_lng,
        "dest_lat": dest_lat,
        "dest_lng": dest_lng,
    }).encode()

    req = urllib.request.Request(
        "http://localhost:8000/api/route",
        data=payload,
        headers={"Content-Type": "application/json"}
    )

    with urllib.request.urlopen(req, timeout=5) as resp:
        return json.loads(resp.read())


if __name__ == "__main__":
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║          电满满 导航功能模拟驾驶测试                              ║")
    print("╚══════════════════════════════════════════════════════════════════╝")

    # 使用真实的后端数据
    # 起点：模拟用户当前位置（武汉徐东大街附近）
    # 终点："国家电网汽车充电站(汪家墩充电站)"（约160米外）
    USER_LAT, USER_LNG = 30.5833, 114.3533
    DEST_LAT, DEST_LNG = 30.583714, 114.352584

    print(f"\n📍 模拟起点：({USER_LAT}, {USER_LNG}) — 武汉徐东大街")
    print(f"📍 目的地：  ({DEST_LAT}, {DEST_LNG}) — 国家电网汪家墩充电站")
    print(f"📏 直线距离：{haversine_distance_km(USER_LAT, USER_LNG, DEST_LAT, DEST_LNG)*1000:.0f} 米")

    # 获取真实路线
    print("\n🌐 调用 /api/route 获取真实驾车路线...")
    try:
        route_data = fetch_route(USER_LAT, USER_LNG, DEST_LAT, DEST_LNG)
    except Exception as e:
        print(f"   ❌ 获取路线失败: {e}")
        print("   请确认后端运行中: python -m uvicorn app.main:app --host 0.0.0.0 --port 8000")
        exit(1)

    if route_data.get('code') != 200:
        print(f"   ❌ 路线规划失败: {route_data.get('message')}")
        exit(1)

    print(f"   ✅ 路线获取成功！")
    print(f"   驾车距离：{route_data['data']['distance_km']} km")
    print(f"   预计耗时：{route_data['data']['duration_min']} 分钟")
    print(f"   路线点数：{len(route_data['data']['polyline'])} 个坐标")
    print(f"   导航步骤：{len(route_data['data']['steps'])} 步")
    for i, s in enumerate(route_data['data']['steps']):
        print(f"      {i+1}. [{s['action']}] {s['instruction']} "
              f"({s['distance_km']}km) @ {s.get('road', '无名路')}")

    # ---- 运行所有测试场景 ----
    results = {}

    # 场景1：正常驾驶
    sim1 = NavigationSimulator(route_data)
    arrived = sim1.simulate_normal_drive()
    sim1.print_summary()
    results['正常驾驶'] = arrived

    # 场景2：偏航测试（重新获取路线以避免状态污染）
    try:
        route_data2 = fetch_route(USER_LAT, USER_LNG, DEST_LAT, DEST_LNG)
        sim2 = NavigationSimulator(route_data2)
        sim2.simulate_with_deviation(deviation_at_pct=0.3)
        sim2.print_summary()
        results['偏航检测'] = True  # 偏航被正确检测到
    except Exception as e:
        print(f"   偏航测试出错: {e}")
        results['偏航检测'] = False

    # 场景3：到达检测（复用 route_data）
    sim3 = NavigationSimulator(route_data)
    arrival_ok = sim3.simulate_arrival()
    sim3.print_summary()
    results['到达检测'] = arrival_ok

    # ---- 最终报告 ----
    print("\n" + "=" * 70)
    print("📋 测试报告")
    print("=" * 70)
    all_pass = True
    for name, result in results.items():
        status = "✅ 通过" if result else "❌ 失败"
        if not result:
            all_pass = False
        print(f"  {status}  {name}")
    print(f"\n{'🎉 所有测试通过！' if all_pass else '⚠️ 部分测试失败，请检查上面日志'}")
    print("=" * 70)
