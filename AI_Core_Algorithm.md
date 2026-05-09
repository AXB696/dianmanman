# Smart Charge 核心算法文档
> AI 可读 · 可视化向量图生成指南 · 评委阅读版

---

## 1. 算法全景图（AI 生图提示词）

```
[COVER IMAGE — 全景图]
A futuristic electric vehicle charging station recommendation system visualization.
Dark blue gradient background with glowing nodes and edges.
Center: a smartphone screen showing a map with multiple charging stations marked with glowing cyan pins.
Connecting lines radiating from the phone to 7 floating hexagonal data modules arranged in a circle.
Each hexagon module glows with a distinct color:
  - Blue hexagon: Distance Scoring Module (log decay curve overlay)
  - Orange hexagon: Dynamic Pricing Module (sine wave representing time-of-use tariff)
  - Red hexagon: Wait Time Module (exponential decay curve)
  - Green hexagon: Power Rating Module (step function chart)
  - Purple hexagon: Fatigue Time Module (24-hour clock with gradient)
  - Teal hexagon: Parking & Availability Module (bar charts)
  - Gold hexagon: Ecosystem Index (shopping district illustration)
Arrows flow from outer modules toward center scoring engine.
Bottom: a route polyline on a map with a driver location marker.
Style: clean infographic, dark theme, neon glow, technical blueprint aesthetic.
```

---

## 2. 七维度评分算法

### 2.1 算法流程图（AI 生图提示词）

```
[ALGORITHM FLOW — 流程图]
Clean dark technical diagram showing the 7-dimension scoring pipeline.
Central large hexagon labeled "Scoring Engine" with 7 input arrows.
Input 1: DISTANCE — glowing blue path from user location to station marker on map
Input 2: PRICE — orange sine wave cycle (24h period) labeled Peak/Valley tariff
Input 3: WAIT TIME — red exponential decay curve e^(-t/15)
Input 4: POWER — green step function: 60kW→80pts, 120kW→100pts
Input 5: FATIGUE — purple radar chart for time-of-day weights
Input 6: PARKING — teal bar: Free=100, 5¥/h=80, 10¥/h=60
Input 7: AVAILABILITY — teal pie chart showing available/total piles
Center output: "FINAL SCORE = Σ wᵢ·Sᵢ + bonus − penalty" in glowing white text.
Style: technical schematic, dark blue background, neon accents, blueprint grid lines.
```

---

### 2.2 核心伪函数（评委版）

#### 综合评分入口

```python
def calculate_score(
    station: dict,
    distance_km: float,
    wait_time_min: int,
    preference: dict,
    dynamic_unit_price: float,
    charging_time_min: int,
    arrival_hour: int,
    parking_fee_per_hour: float,
) -> ScoreResult:
    """
    七维度加权评分 + 实时数据注入 + 洞察生成
    返回: { score: float, breakdown: dict, bonus: float, penalty: float }
    """

    # ── 维度1: 距离评分 (对数衰减) ──
    S_dist = score_distance(distance_km, preference.get('prefer_near', True))

    # ── 维度2: 电价评分 (Sigmoid 定价) ──
    S_price = score_price(dynamic_unit_price, arrival_hour)

    # ── 维度3: 等待时间评分 (指数衰减) ──
    S_wait = score_wait_time(wait_time_min)

    # ── 维度4: 功率评分 (分段函数) ──
    power_kw = station.get('power_kw', 60)
    S_power = score_power(power_kw)

    # ── 维度5: 疲劳时间评分 (24h 时段加权) ──
    S_fatigue = score_fatigue(arrival_hour, charging_time_min)

    # ── 维度6: 停车费用评分 ──
    S_parking = score_parking(parking_fee_per_hour)

    # ── 维度7: 可用性评分 (空闲桩占比) ──
    S_avail = score_availability(station)

    # ── 权重向量 W = [0.25, 0.25, 0.20, 0.15, 0.05, 0.05, 0.05] ──
    W = WEIGHT_VECTOR
    S = [S_dist, S_price, S_wait, S_power, S_fatigue, S_parking, S_avail]

    raw_score = sum(w * s for w, s in zip(W, S))

    # ── 可达性惩罚 ──
    penalty = compute_reachability_penalty(station, distance_km)

    # ──  Bonus: 周边生态 ──
    bonus = compute_ecosystem_bonus(station)

    final_score = clamp(raw_score + bonus - penalty, 0, 100)

    return ScoreResult(
        score=round(final_score, 2),
        breakdown={dim: round(s, 2) for dim, s in zip(DIM_NAMES, S)},
        bonus=round(bonus, 2),
        penalty=round(penalty, 2)
    )
```

#### 维度1: 距离评分（对数衰减）

```python
def score_distance(d_km: float, prefer_near: bool = True) -> float:
    """
    基于对数衰减的距离归一化评分
    原理: 用户对距离感知呈对数关系（近处敏感，远处钝化）

    f(d) = 100 / (1 + α · ln(1 + d))

    超参数:
        α = 0.35 (衰减系数)
        d ∈ [0, 100] km
    """
    ALPHA = 0.35
    if d_km <= 0:
        return 100.0
    score = 100.0 / (1 + ALPHA * math.log(1 + d_km))
    return score * (0.95 if prefer_near else 1.05)   # 偏好系数微调
```

**评分曲线可视化提示词**：
```
[CHART — Distance Score Decay]
Line chart on dark background.
X-axis: distance_km from 0 to 50.
Y-axis: score from 0 to 100.
Blue glowing curve: y = 100/(1+0.35*ln(1+x)), strictly decreasing.
At x=0, y=100. At x=5km, y≈75. At x=15km, y≈55. At x=30km, y≈42.
Red dashed reference line at y=50 (threshold).
Neon blue line with subtle glow effect. Grid lines in dark gray.
Style: technical matplotlib style, dark mode.
```

#### 维度2: 电价评分（Sigmoid 动态定价）

```python
def score_price(unit_price: float, arrive_hour: int) -> float:
    """
    基于 Sigmoid 的电价敏感度评分
    原理: 用户对电价敏感度呈 S 型曲线（低价区/高价区敏感，中价区钝感）

    武汉分时电价基准: 1.65 元/kWh
    峰谷价差比: 0.86 / 1.95 ≈ 2.27x

    f(p) = 100 / (1 + e^{k·(p − p_mid)})

    超参数:
        k = 3.5 (敏感度陡度)
        p_mid = 1.65 (基准电价，中位敏感点)
    """
    K = 3.5
    P_MID = 1.65
    p = max(0.01, unit_price)

    sigmoid_val = 1.0 / (1.0 + math.exp(K * (p - P_MID)))
    # 反转：低价得高分
    score = 100.0 * (1.0 - sigmoid_val)

    # 谷时额外加权（行为经济学：峰谷差异放大效应）
    if is_valley_hour(arrive_hour):
        score *= 1.08   # 谷时 +8% 加权

    return clamp(score, 0, 100)
```

**评分曲线可视化提示词**：
```
[CHART — Price Sigmoid Scoring]
Sigmoid curve on dark background, X-axis: price 0.5 to 2.5 yuan/kWh.
Y-axis: score 0 to 100.
Steep orange curve crossing (1.65, 50): at 0.86 yuan y≈90, at 1.65 yuan y≈50, at 1.95 yuan y≈15.
Point annotations: "谷时 0.86¥" (left, high), "基准 1.65¥" (center, 50), "尖峰 1.95¥" (right, low).
Orange neon glow on curve. Dashed horizontal line at y=50.
Style: technical chart, dark mode.
```

#### 维度3: 等待时间评分（指数衰减）

```python
def score_wait_time(wait_min: int) -> float:
    """
    基于指数衰减的等待时间评分
    原理: 用户等待痛苦度随时间非线性增长，前几分钟痛苦值快速上升

    f(t) = 100 · e^{−t/τ}

    超参数:
        τ = 15 min (特征时间常数)
        wait_min ∈ [0, 120]
    """
    TAU = 15
    if wait_min <= 0:
        return 100.0
    score = 100.0 * math.exp(-wait_min / TAU)
    return clamp(score, 0, 100)
```

#### 维度4: 功率评分（分段函数）

```python
def score_power(power_kw: float) -> float:
    """
    充电功率分段评分
    原理: 用户感知存在关键阈值：60kW 以上差异感知减弱

    f(p) =
        100,  if p ≥ 120 kW   (超快充，体验极佳)
        80,  if 60 ≤ p < 120  (快充，满意)
        60,  if 30 ≤ p < 60   (慢充，勉强接受)
        40,  if p < 30 kW     (不推荐)
    """
    if power_kw >= 120:
        return 100.0
    elif power_kw >= 60:
        return 80.0
    elif power_kw >= 30:
        return 60.0
    else:
        return 40.0
```

**功率评分可视化提示词**：
```
[CHART — Power Step Function]
Step function chart on dark background.
X-axis: charging power kW from 0 to 180.
Y-axis: score 0 to 100.
Red stepped horizontal lines:
  0-30kW: y=40 (gray zone)
  30-60kW: y=60 (acceptable)
  60-120kW: y=80 (good)
  120+kW: y=100 (excellent)
Annotated threshold markers with arrows.
Neon red/orange/green gradient on steps.
Style: technical step chart, dark mode.
```

#### 维度5: 疲劳时间评分（24h 时段加权）

```python
def score_fatigue(arrival_hour: int, charge_duration_min: int) -> float:
    """
    基于时段加权与充电时长的疲劳评分
    原理: 不同时段驾驶疲劳程度不同，夜间凌晨最危险

    时间权重表 W_time (24h, 归一化到 [0,1]):
        00-06h: 低 (0.50) — 深夜疲劳
        06-09h: 高 (0.85) — 早高峰
        09-12h: 中 (0.70) — 上午
        12-14h: 中 (0.70) — 午间
        14-18h: 高 (0.85) — 下午高峰
        18-21h: 中 (0.70) — 傍晚
        21-24h: 低 (0.55) — 夜间

    f = W_time[hour] × W_charge
    W_charge = e^{−duration/180}  (充电时长衰减，τ=3h)
    """
    TIME_WEIGHTS = {
        range(0,6):  0.50,
        range(6,9):  0.85,
        range(9,12): 0.70,
        range(12,14):0.70,
        range(14,18):0.85,
        range(18,21):0.70,
        range(21,24):0.55,
    }

    w_time = next((v for r,v in TIME_WEIGHTS.items() if arrival_hour in r), 0.70)
    w_charge = math.exp(-charge_duration_min / 180.0)

    return 100.0 * w_time * w_charge
```

**疲劳热力图可视化提示词**：
```
[CHART — 24h Fatigue Heatmap]
Radial 24-hour heatmap on dark background, circular clock layout.
24 segments around the circle, colored by fatigue weight:
  Center (0-6h): dark blue, low weight 0.50 — deep night danger zone
  Inner ring morning (6-9h): bright orange-red, weight 0.85 — morning rush
  Middle ring midday (9-14h): yellow, weight 0.70
  Outer ring afternoon (14-18h): bright orange, weight 0.85 — afternoon rush
  Outer ring evening (18-21h): yellow, weight 0.70
  Outer ring night (21-24h): dark blue, weight 0.55
Numbers 0-24 around the perimeter.
Neon glow on high-weight segments.
Style: circular heatmap, dark mode, technical radar aesthetic.
```

#### 维度6: 停车费用评分

```python
def score_parking(parking_fee_per_hour: float) -> float:
    """
    停车费用评分
    原理: 停车费对用户总成本影响显著，免费停车提供显著正效用

    f(fee) =
        100,                    if fee = 0 (免费)
        100 − fee × 4,         if 0 < fee ≤ 10
        max(40, 60 − fee),     if fee > 10
    """
    if parking_fee_per_hour <= 0:
        return 100.0
    elif parking_fee_per_hour <= 10:
        return max(40.0, 100.0 - parking_fee_per_hour * 4.0)
    else:
        return max(40.0, 60.0 - parking_fee_per_hour * 0.5)
```

#### 维度7: 可用性评分（空闲桩占比）

```python
def score_availability(station: dict) -> float:
    """
    可用性评分：空闲桩占比 × 运营商信誉加权
    原理: 用户更倾向选择空闲桩多、运营商信誉好的站点

    f = min(100, available_count / total_count × 100 × operator_credit)
    operator_credit: 国家电网=1.2, 特来电=1.1, 星星充电=1.0, 其他=0.9
    """
    avail = station.get('availability', {})
    total = avail.get('total', 1)
    available = avail.get('available', 0)

    if total <= 0:
        return 50.0

    ratio = available / total
    operator = station.get('operator', 'other')
    CREDIT = {'sgcc': 1.2, 'tel': 1.1, 'star': 1.0}
    credit = CREDIT.get(operator.lower()[:4], 0.9)

    score = ratio * 100.0 * credit
    return clamp(score, 0, 100)
```

---

## 3. 能耗可达性模型

```python
def can_reach(
    current_soc: float,
    battery_capacity: float,
    energy_consumption: float,   # kWh/100km
    distance_km: float,
    temperature_c: float = 25.0,
) -> bool:
    """
    电池可达性判断（含温度热衰减 + 30% 安全缓冲）

    步骤:
    1. 根据气温计算热衰减系数 τ(t):
        t ≤ 5°C  → τ = 1.35  (暖风消耗 + 电池活性下降)
        t ≥ 35°C → τ = 1.20  (空调高负荷)
        t ∈ [5,35] → τ = 1.0

    2. 有效能耗 = energy_consumption × τ(t)

    3. 可用电量 = current_soc / 100 × battery_capacity

    4. 最大可行驶距离 = 可用电量 / (有效能耗 / 100)

    5. 安全距离 = 最大可行驶距离 × 0.7  (保留 30% 电量缓冲)

    6. 返回: distance_km ≤ 安全距离
    """
    degradation = get_thermal_degradation(temperature_c)
    real_consumption = energy_consumption * degradation
    available_energy = (current_soc / 100.0) * battery_capacity
    max_distance = available_energy / (real_consumption / 100.0) if real_consumption > 0 else 0
    safe_distance = max_distance * 0.7
    return distance_km <= safe_distance
```

**能耗热衰减可视化提示词**：
```
[CHART — Temperature Degradation Curve]
Line chart showing battery degradation factor vs temperature.
X-axis: temperature -10°C to 45°C.
Y-axis: degradation factor 0.9 to 1.4.
Three zones highlighted:
  Left zone (t≤5°C): red zone, factor rises to 1.35 — cold weather penalty
  Center zone (5-35°C): green zone, factor=1.0 — optimal
  Right zone (t≥35°C): orange zone, factor rises to 1.20 — heat penalty
Annotated curves with arrows showing transition points at 5°C and 35°C.
Neon glow effect, dark background.
Style: technical chart, dark mode.
```

---

## 4. 武汉分时电价模型

```python
"""
武汉地区典型分时电价结构（2024年参考：工商业及其他用电）
基准电价: 1.65 元/kWh（含服务费参考值）

分时时段系数:
    尖峰 11:00-13:00, 18:00-20:00  → 系数 1.18 → 实际约 1.95 元/kWh
    高峰  08:00-11:00, 13:00-18:00 → 系数 1.08 → 实际约 1.78 元/kWh
    平段  07:00-08:00, 20:00-23:00 → 系数 1.00 → 实际约 1.65 元/kWh
    谷段  23:00-07:00             → 系数 0.52 → 实际约 0.86 元/kWh
"""

_TARIFF = {
    "sharp": (11,12,18,19),    # 尖峰
    "peak":  (8,9,10,13,14,15,16,17),  # 高峰
    "flat":  (7,20,21,22),      # 平段
    "valley":(0,1,2,3,4,5,6,23), # 谷段
}

_COEFFICIENT = {"sharp": 1.18, "peak": 1.08, "flat": 1.00, "valley": 0.52}

def get_unit_price(arrive_hour: int) -> float:
    """到达时段对应的综合电价（元/kWh）"""
    period = classify_tariff_period(arrive_hour)
    return round(_BASE_PRICE * _COEFFICIENT[period], 3)
```

**24h 电价曲线可视化提示词**：
```
[CHART — 24h Time-of-Use Tariff]
Area chart on dark background, 24-hour timeline.
Four colored zones:
  Valley (23-7h): large blue area under curve, 0.86 yuan/kWh — deep blue fill
  Flat (7-8h, 20-23h): medium yellow area, 1.65 yuan/kWh
  Peak (8-11h, 13-18h): orange area, 1.78 yuan/kWh
  Sharp (11-13h, 18-20h): bright red/pink area, 1.95 yuan/kWh
Labels on peaks: "尖峰 1.95¥" and "高峰 1.78¥" and "谷时 0.86¥"
Dashed horizontal reference line at 1.65 (base price).
Neon glow on peak areas, dark blue on valley.
Style: beautiful area chart, dark mode.
```

---

## 5. 周边生态指数

```python
async def compute_ecosystem_bonus(station: dict) -> float:
    """
    周边生态便利指数
    数据来源: 高德 POI 周边搜索 API

    搜索类型: 餐饮服务 | 购物服务 | 休闲娱乐
    搜索半径: 1000m

    加分规则:
        bonus = min(10.0, count_total × 0.5)
        上限 10 分（最多 20 个有效 POI）
    """
    lat = station["location"]["lat"]
    lng = station["location"]["lng"]

    poi_data = await AMapService.get_amenities_around(lat, lng)

    if not poi_data["success"] or poi_data["count"] == 0:
        return 0.0

    count = poi_data["count"]
    bonus_score = min(10.0, count * 0.5)

    return bonus_score
```

**周边生态可视化提示词**：
```
[ILLUSTRATION — Ecosystem Index]
Top-down map view of charging station location (center).
Concentric circles radiating outward: 300m, 600m, 1000m radius.
Small icons within circles: fork+knife (restaurants), shopping bag (stores),
  coffee cup (cafes), film reel (entertainment).
Circle count: 12 POI markers in teal glowing dots.
Station pin at center with bonus score "+10" badge.
Bottom legend: "12 POIs × 0.5 = +10 bonus score".
Style: map overlay infographic, dark mode, neon accents.
```

---

## 6. 洞察消息生成规则

```python
def generate_insight(price_info: dict, wait_time: int, arrive_hour: int,
                    degradation: float, S_price: float, S_wait: float) -> str:
    """
    多条件洞察消息生成（优先级: 谷时 > 等谷电 > 预警 > 高价 > 周边）
    """
    parts = []
    period = price_info["period"]

    # 1. 谷时低价推荐（电价 < 0.95 且谷时）
    if period == "valley" and price_info["unit_price"] < 0.95:
        parts.append("🌟 谷时低价推荐({:.2f}元/kWh)".format(price_info["unit_price"]))

    # 2. 尖峰等谷策略（尖峰时段建议等待进谷，省钱计算）
    elif period == "sharp":
        wait_mins = compute_valley_wait(arrive_hour)
        if wait_mins > 0 and wait_mins <= 60:
            valley_cost = compute_valley_cost(price_info)
            saving = round(price_info["cost"] - valley_cost, 2)
            parts.append("⏰ 等{}min享谷电(省¥{})".format(wait_mins, saving))
        else:
            parts.append("⚠️ 尖峰时段({:.2f}元/kWh)".format(price_info["unit_price"]))

    # 3. 能耗预警（低温/高温）
    if degradation > 1.0:
        pct = int((degradation - 1) * 100)
        parts.append("⚠️ {}°C 能耗+{}%".format(current_temp, pct))

    # 4. 等待预警
    if S_wait < 30 and wait_time > 0:
        parts.append("⚠️ 等桩{}min".format(wait_time))

    # 5. 高价预警
    if S_price < 30:
        parts.append("💰 电价偏高({:.2f}元)".format(price_info["unit_price"]))

    # 6. 周边生态（已在前面阶段追加）
    # 7. 谷时低价（平谷但不便宜）
    elif period == "valley":
        parts.append("🌙 谷时段({:.2f}元/kWh)".format(price_info["unit_price"]))

    return " | ".join(parts) if parts else ""
```

---

## 7. 推荐评分权重总结

```
┌─────────────────────────────────────────────────────────┐
│           七维度评分权重配置 (W ∈ R⁷)                    │
├──────────┬──────────┬──────────┬──────────────────────────┤
│ 维度      │ 符号      │ 权重 wᵢ  │ 评分函数                │
├──────────┼──────────┼──────────┼──────────────────────────┤
│ 距离      │ S_dist   │ 0.25     │ f(d)=100/(1+α·ln(1+d))  │
│ 电价      │ S_price  │ 0.25     │ f(p)=sigmoid(p,p_mid)   │
│ 等待      │ S_wait   │ 0.20     │ f(t)=100·e^{−t/τ}       │
│ 功率      │ S_power  │ 0.15     │ 分段常数: 100/80/60/40  │
│ 疲劳      │ S_fatigue│ 0.05     │ f=W_time·W_charge       │
│ 停车      │ S_parking│ 0.05     │ f=100−fee×4 (上限)      │
│ 可用      │ S_avail  │ 0.05     │ f=ratio×credit×100      │
└──────────┴──────────┴──────────┴──────────────────────────┘

综合评分公式:
    Score = Σᵢ wᵢ · Sᵢ + bonus − penalty
          = 0.25·S_dist + 0.25·S_price + 0.20·S_wait + 0.15·S_power
            + 0.05·S_fatigue + 0.05·S_parking + 0.05·S_avail + bonus − penalty

约束条件:
    Score ∈ [0, 100]
    bonus ≥ 0, penalty ≥ 0
    bonus = ecosystem_bonus (上限 10.0)
    penalty = reachability_penalty (超距离时触发)
```

---

## 8. 算法复杂度分析

| 阶段 | 时间复杂度 | 说明 |
|---|---|---|
| district/type 过滤 | O(N) | 单遍历，N=全部站点数 |
| bounding box 过滤 | O(N) | 与上合并 |
| Haversine 距离 | O(N) | 与上合并 |
| 排序（top-N） | O(N log N) | 取 top-5 |
| 高德路线（Top-5并发） | O(1) | 恒定5次API调用，并发=5 |
| 七维度评分 | O(N) | 纯内存计算 |
| 周边POI（Top-5并发） | O(1) | 恒定5次API调用 |
| **总最坏复杂度** | **O(N log N)** | N=500~2000站点 |
| **实际平均复杂度** | **O(N)** | bounding box 提前剪枝，实际遍历 << N |
