"""
电池服务：能耗模型 + 充电时间估算 + 真实峰谷电价
数据来源: 湖北省电网公开电价（工商业及其他用电）

武汉地区典型分时电价结构（2024年参考）：
  尖峰: 11:00-13:00 / 18:00-20:00  (约 1.15-1.20 × 基准)
  高峰: 08:00-11:00 / 13:00-18:00  (约 1.05-1.10 × 基准)
  平段: 07:00-08:00 / 20:00-23:00
  谷段: 23:00-次日07:00            (约 0.5-0.6 × 基准)

尖峰时段和高峰时段电价显著高于基准，谷段约为基准的 50%-60%。
"""
from datetime import datetime


# 武汉地区典型分时电价（元/kWh，含服务费参考值）
_WUHAN_PEAK_HOURS = {8, 9, 10, 13, 14, 15, 16, 17}           # 高峰
_WUHAN_SHARP_HOURS = {11, 12, 18, 19}                         # 尖峰
_WUHAN_VALLEY_HOURS = {0, 1, 2, 3, 4, 5, 6, 23}              # 谷段

# 各时段电价系数（以基准电价 1.65 元/kWh 为基准）
# 实际电价 = 系数 × 基准电价
_TARIFF_COEFFICIENT = {
    "sharp": 1.18,    # 尖峰: 约 1.95 元/kWh
    "peak":   1.08,   # 高峰: 约 1.78 元/kWh
    "flat":   1.00,   # 平段: 约 1.65 元/kWh
    "valley": 0.52,   # 谷段: 约 0.86 元/kWh
}

_BASE_PRICE = 1.65    # 武汉地区参考基准电价（元/kWh，含服务费）

# 谷电激励阈值（到达电价低于此值时触发谷电推荐）
_VALLEY_PRICE_THRESHOLD = 0.95   # 元/kWh

# 峰电惩罚阈值（到达电价高于此值时显示价格预警）
_PEAK_PRICE_WARN_THRESHOLD = 1.80


class BatteryService:

    @staticmethod
    def get_thermal_degradation(temperature_c: float) -> float:
        """
        基于温度折算能耗衰减系数。
        低于5°C(暖风+电池活性下降) → ×1.35
        高于35°C(空调) → ×1.20
        正常室温 → ×1.0
        """
        if temperature_c <= 5:
            return 1.35
        elif temperature_c >= 35:
            return 1.20
        return 1.0

    @staticmethod
    def can_reach(
        current_soc: float,
        battery_capacity: float,
        energy_consumption: float,
        distance: float,
        temperature_c: float = 25.0
    ) -> bool:
        degradation = BatteryService.get_thermal_degradation(temperature_c)
        real_consumption = energy_consumption * degradation
        available_energy = (current_soc / 100) * battery_capacity
        max_distance = available_energy / (real_consumption / 100) if real_consumption > 0 else 0
        safe_distance = max_distance * 0.7   # 保留 30% 电量缓冲
        return distance <= safe_distance

    @staticmethod
    def estimate_charging_time(
        current_soc: float,
        target_soc: float,
        battery_capacity: float,
        power_kw: float,
        station_type: str
    ) -> int:
        """估算充电时长（分钟）"""
        if station_type == "swap":
            return 5   # 换电约5分钟

        energy_needed = max(0, (target_soc - current_soc) / 100) * battery_capacity
        effective_power = power_kw * 0.8   # 充电曲线平均效率 80%

        if effective_power <= 0:
            return 60

        return int(energy_needed / effective_power * 60)

    @staticmethod
    def _get_tariff_coefficient(hour: int) -> str:
        """根据小时返回时段标识"""
        if hour in _WUHAN_SHARP_HOURS:
            return "sharp"
        elif hour in _WUHAN_PEAK_HOURS:
            return "peak"
        elif hour in _WUHAN_VALLEY_HOURS:
            return "valley"
        else:
            return "flat"

    @staticmethod
    def get_unit_price(arrive_hour: int) -> float:
        """
        获取指定到达时段的综合电价（元/kWh）。
        含基准电价 + 服务费。
        """
        period = BatteryService._get_tariff_coefficient(arrive_hour)
        coeff = _TARIFF_COEFFICIENT[period]
        return round(_BASE_PRICE * coeff, 3)

    @staticmethod
    def estimate_cost(
        station: dict,
        battery_capacity: float,
        target_soc: float,
        current_soc: float,
        arrive_duration_mins: int = 0
    ) -> dict:
        """
        估算充电费用，使用真实分时电价。
        """
        energy_needed = max(0, (target_soc - current_soc) / 100) * battery_capacity

        # 到达时间（含途中耗时）
        now = datetime.now()
        arrive_hour = (now.hour + (now.minute + arrive_duration_mins) // 60) % 24
        arrive_minute = (now.minute + arrive_duration_mins) % 60

        # 基础电价（含服务费）
        base_elec = station.get("price", {}).get("electricity", _BASE_PRICE)
        service_fee = station.get("price", {}).get("service_fee", 0.0)

        # 动态时段电价
        period = BatteryService._get_tariff_coefficient(arrive_hour)
        coeff = _TARIFF_COEFFICIENT[period]

        # 运营商原始电价 × 时段系数（避免覆盖真实运营商定价）
        actual_elec = base_elec * coeff
        real_total_price = actual_elec + service_fee
        total_cost = round(energy_needed * real_total_price, 2)

        # 洞察消息
        insight_msg = ""

        if period == "valley":
            if real_total_price < _VALLEY_PRICE_THRESHOLD:
                insight_msg = f"🌟 谷时低价推荐({real_total_price:.2f}元/kWh)"
            else:
                insight_msg = f"🌟 谷时段({real_total_price:.2f}元/kWh)"
        elif period == "sharp":
            wait_mins = 0
            # 检查是否可以在谷时段到达（等几分钟进谷）
            if arrive_hour == 18:
                wait_mins = 60 - arrive_minute   # 等到 20:00 进谷
            elif arrive_hour == 11:
                wait_mins = 60 - arrive_minute   # 等到 13:00 进谷
            if wait_mins > 0 and wait_mins <= 60:
                valley_cost = round(energy_needed * (base_elec * _TARIFF_COEFFICIENT["valley"] + service_fee), 2)
                saving = round(total_cost - valley_cost, 2)
                insight_msg = f"⏰ 等{wait_mins}min享谷电(省¥{saving})"
            else:
                insight_msg = f"⚠️ 尖峰时段({real_total_price:.2f}元/kWh)"
        elif period == "peak":
            insight_msg = f"⏰ 高峰时段({real_total_price:.2f}元/kWh)"

        return {
            "cost": total_cost,
            "unit_price": round(real_total_price, 3),
            "period": period,
            "insight": insight_msg
        }
