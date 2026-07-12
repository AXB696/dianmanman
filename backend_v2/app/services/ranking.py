"""
充电站推荐核心评分算法
设计原则：对数/Sigmoid/指数衰减符合用户心理，精准区分场景
"""
import math
from datetime import datetime
from typing import Optional


# ============== 算法参数（可调） ==============
# 距离参数
_DIST_REF = 30.0           # 参考距离(km)，对数曲线拐点
_DIST_MAX = 80.0           # 最大有效距离(km)，超出基本不考虑

# 价格参数
_PRICE_REF = 1.65          # 武汉地区电价均值(元/kWh)
_PRICE_K = 4.0             # Sigmoid锐度，越大曲线越陡

# 功率映射分段阈值
_POWER_SLOW_MAX = 7        # 慢充 ≤7kW
_POWER_FAST_MAX = 60       # 快充 ≤60kW
_POWER_ULTRA_MIN = 60      # 超充 >60kW

# 等桩时间常数(min) — 15min为心理临界点
_WAIT_TAU = 15.0

# 疲劳时间常数(h) — 3h为长途疲劳临界点
_FATIGUE_TAU = 3.0

# 加分阈值
_VALLEY_PRICE_THRESHOLD = 0.5  # 谷电价格门槛(元/kWh)


# ============== 各维度评分函数 ==============

def score_distance(distance_km: float) -> float:
    """
    距离评分：对数衰减
    · 1-5km:   快速递增梯度（近者优先）
    · 5-30km:  平缓递减（均衡考量）
    · 30km+:   缓慢趋近0
    范围: [0, 100]
    """
    if distance_km <= 0:
        return 100.0
    # 对数归一化: ln(distance+1)/ln(_DIST_MAX+1) → 越近越高
    return max(0.0, min(100.0, 100.0 * math.log((_DIST_MAX + 1) / (distance_km + 1)) / math.log(_DIST_MAX + 1)))


def score_price(total_price_per_kwh: float) -> float:
    """
    价格评分：Sigmoid平滑
    · 1.0元: ~90分
    · 1.65元(均值): 50分
    · 2.5元+: ~10分
    范围: [0, 100]
    """
    if total_price_per_kwh <= 0:
        return 100.0
    # Sigmoid: 100 / (1 + e^(k·(price - ref)))
    exponent = _PRICE_K * (total_price_per_kwh - _PRICE_REF)
    # 防止 overflow
    if exponent > 700:
        return 0.0
    return max(0.0, min(100.0, 100.0 / (1.0 + math.exp(exponent))))


def score_wait_time(wait_time_min: int, available: int, total: int) -> float:
    """
    等桩评分：指数衰减
    · 0min:   100分
    · 15min:  ~37分
    · 45min+: →0
    同时叠加可用桩比例惩罚
    范围: [0, 100]
    """
    base = 100.0 * math.exp(-wait_time_min / _WAIT_TAU)
    # 可用桩比例: 有桩空闲才值得推荐
    if total > 0:
        avail_ratio = available / total
        # 全满时额外惩罚
        if avail_ratio <= 0:
            base *= 0.2
        elif avail_ratio < 0.3:
            base *= 0.6
        elif avail_ratio < 0.5:
            base *= 0.8
    return max(0.0, min(100.0, base))


def score_power(power_kw: float, station_type: str) -> float:
    """
    功率评分：分段映射
    · 换电(swap):  90分（机制特殊，体验最优）
    · 超充(>60kW): 75-95分，功率越高分越高
    · 快充(7-60kW): 50-70分，日常主力
    · 慢充(≤7kW):  20-40分，目的地场景
    范围: [0, 100]
    """
    if station_type == "swap":
        return 90.0

    if power_kw <= 0:
        return 20.0

    if power_kw <= _POWER_SLOW_MAX:
        # 慢充线性: 20-40
        return 20.0 + (power_kw / _POWER_SLOW_MAX) * 20.0
    elif power_kw <= _POWER_FAST_MAX:
        # 快充线性: 40-70
        return 40.0 + ((power_kw - _POWER_SLOW_MAX) / (_POWER_FAST_MAX - _POWER_SLOW_MAX)) * 30.0
    else:
        # 超充对数: 70-95，功率边际效益递减
        ultra_ratio = min(1.0, (power_kw - _POWER_FAST_MAX) / 180.0)  # 以180kW为上限
        return 70.0 + 25.0 * math.log(1.0 + ultra_ratio * 9.0) / math.log(10.0)


def score_fatigue(total_time_hours: float) -> float:
    """
    疲劳评分：指数衰减总时间成本
    行驶时间 + 充电时间 + 等桩时间 统一量化
    · <1h:  96分
    · 3h:   37分
    · 6h+: →0
    范围: [0, 100]
    """
    if total_time_hours <= 0:
        return 100.0
    return max(0.0, min(100.0, 100.0 * math.exp(-total_time_hours / _FATIGUE_TAU)))


def score_parking(parking_fee_per_hour: float, charging_time_min: int) -> float:
    """
    停车费评分：隐性成本
    充电时间内停车费总额 → 成本惩罚
    · 免费停车: +5分 bonus
    · 收费: 停车费/充电时间占比越高，扣分越多
    范围: [0, 100]
    """
    if parking_fee_per_hour <= 0:
        return 100.0  # 免费停车

    # 估算充电期间停车费总额
    charging_hours = charging_time_min / 60.0
    total_parking_cost = parking_fee_per_hour * charging_hours

    # 每10元停车费扣20分，上限100分（扣完）
    penalty = min(100.0, total_parking_cost * 2.0)
    return max(0.0, 100.0 - penalty)


def score_availability(available: int, total: int) -> float:
    """
    可用桩比例评分
    范围: [0, 100]
    """
    if total <= 0:
        return 0.0
    ratio = available / total
    return max(0.0, min(100.0, ratio * 100.0))


# ============== 峰谷时段判断 ==============

def is_valley_hour(arrive_hour: int) -> bool:
    """判断是否谷时段（20:00-07:00）"""
    return arrive_hour >= 20 or arrive_hour < 7


def is_peak_hour(arrive_hour: int) -> bool:
    """判断是否尖峰时段（11-13点, 18-21点）"""
    return 11 <= arrive_hour <= 13 or 18 <= arrive_hour <= 21


# ============== 主评分函数 ==============

def calculate_score(
    station: dict,
    distance_km: float,
    wait_time_min: int,
    preference,
    dynamic_unit_price: float,
    charging_time_min: int,
    arrival_hour: int,
    parking_fee_per_hour: float = 0.0,
) -> dict:
    """
    综合评分函数

    参数:
        station:              电站完整字典
        distance_km:          直线距离(km)
        wait_time_min:         等桩时间(min)，从 station['availability']['wait_time'] 获取
        preference:            用户偏好权重对象
        dynamic_unit_price:   动态计算的综合电价(元/kWh)
        charging_time_min:     预估充电时长(min)
        arrival_hour:         预计到达小时(0-23)
        parking_fee_per_hour:  停车费(元/时)，从 station['price']['parking_fee'] 获取

    返回:
        dict: {
            'score': float,       # 综合评分
            'breakdown': dict,    # 各维度分数详情（调试用）
            'bonus': float,       # 加分项小计
            'penalty': float,     # 惩罚项小计
        }
    """
    # --- 各维度原始分 ---
    avail_data = station.get("availability", {})
    available = avail_data.get("available", 0)
    total_piles = avail_data.get("total", 0)

    S_dist = score_distance(distance_km)
    S_price = score_price(dynamic_unit_price)
    S_wait = score_wait_time(wait_time_min, available, total_piles)
    S_power = score_power(station.get("power_kw", 60), station.get("type"))
    S_avail = score_availability(available, total_piles)

    # --- 疲劳成本 ---
    # 总时间 = 行驶时间(distance/35km/h) + 充电时间 + 等桩时间
    drive_hours = distance_km / 35.0
    charge_hours = charging_time_min / 60.0
    wait_hours = wait_time_min / 60.0
    total_time_hrs = drive_hours + charge_hours + wait_hours
    S_fatigue = score_fatigue(total_time_hrs)

    # --- 停车费 ---
    S_parking = score_parking(parking_fee_per_hour, charging_time_min)

    # --- 权重归一化 ---
    total_weight = (
        preference.distance_weight
        + preference.price_weight
        + preference.wait_time_weight
        + preference.power_weight
    )
    if total_weight <= 0:
        total_weight = 1.0

    # --- 加权求和 ---
    weighted_sum = (
        S_dist * preference.distance_weight
        + S_price * preference.price_weight
        + S_wait * preference.wait_time_weight
        + S_power * preference.power_weight
    )
    base_score = weighted_sum / total_weight

    # --- 辅助维度加成（固定权重，不受 preference 控制） ---
    extra_score = (S_fatigue * 0.3 + S_parking * 0.1 + S_avail * 0.2) / 0.6

    # --- 加分项 ---
    bonus = 0.0

    # 超充急迫加成
    if preference.prefer_ultra and station.get("type") == "ultra":
        bonus += 10.0

    # 夜间谷电激励：到达在谷时 且 电价低于阈值
    if is_valley_hour(arrival_hour) and dynamic_unit_price < _VALLEY_PRICE_THRESHOLD:
        valley_bonus = 10.0 + (0.5 - dynamic_unit_price) * 40.0  # 越便宜加越多
        bonus += valley_bonus

    # 免停车费激励
    if parking_fee_per_hour <= 0:
        bonus += 5.0

    # --- 惩罚项 ---
    penalty = 0.0

    # 高峰涨价惩罚
    if is_peak_hour(arrival_hour) and dynamic_unit_price > 2.0:
        penalty -= 8.0

    # 全占用惩罚（等桩时间很长且无可用桩）
    if total_piles > 0 and available == 0 and wait_time_min > 30:
        penalty -= 15.0

    # 最终评分
    final_score = base_score * 0.85 + extra_score * 0.15 + bonus + penalty
    final_score = max(0.0, min(100.0, round(final_score, 2)))

    return {
        "score": final_score,
        "breakdown": {
            "S_dist": round(S_dist, 1),
            "S_price": round(S_price, 1),
            "S_wait": round(S_wait, 1),
            "S_power": round(S_power, 1),
            "S_fatigue": round(S_fatigue, 1),
            "S_parking": round(S_parking, 1),
            "S_avail": round(S_avail, 1),
        },
        "bonus": round(bonus, 1),
        "penalty": round(penalty, 1),
    }
