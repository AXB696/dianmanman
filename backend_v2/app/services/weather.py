"""
天气服务：获取真实气温，用于电池热衰减模型
"""
import httpx


class WeatherService:
    # 缓存：避免同一请求内多次调用外部 API
    _cache: dict = {}

    @staticmethod
    async def get_current_temperature_async(lat: float, lng: float) -> float:
        """
        异步获取指定坐标的真实气温（Open-Meteo API，无 KEY）。
        返回: 气温(°C)
        """
        cache_key = (round(lat, 2), round(lng, 2))
        if cache_key in WeatherService._cache:
            return WeatherService._cache[cache_key]

        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lng}"
            f"&current_weather=true"
        )
        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                response = await client.get(url)
                if response.status_code == 200:
                    data = response.json()
                    temp = float(data.get("current_weather", {}).get("temperature", 20.0))
                    WeatherService._cache[cache_key] = temp
                    return temp
        except Exception:
            pass

        # 降级：返回常温（不触发热衰减惩罚）
        return 20.0

    @staticmethod
    def get_current_temperature(city: str = "Wuhan") -> float:
        """
        同步版本（向后兼容，内部调用已弃用，直接用异步版本）。
        武汉默认返回 20°C。
        """
        return 20.0
