import httpx
import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)


class AMapService:
    API_KEY = os.getenv("AMAP_KEY", "5595bdb2b42e61f60d48aec7166a207c")
    BASE_URL = "https://restapi.amap.com/v3"

    # 连接池复用（模块级单例，避免每次请求都新建 TCP 连接）
    _client: Optional[httpx.AsyncClient] = None

    @classmethod
    def _get_client(cls) -> httpx.AsyncClient:
        if cls._client is None or cls._client.is_closed:
            cls._client = httpx.AsyncClient(
                timeout=httpx.Timeout(5.0),
                limits=httpx.Limits(max_keepalive_connections=20, max_connections=100),
            )
        return cls._client

    @classmethod
    async def close_client(cls):
        if cls._client and not cls._client.is_closed:
            await cls._client.aclose()
            cls._client = None

    @staticmethod
    async def get_amenities_around(lat: float, lng: float, radius: int = 1000) -> dict:
        """
        获取周边生态环境（打发时间指数）。
        查询类型: 050000(餐饮), 060000(购物), 080000(体育休闲), 200300(公共厕所)
        """
        url = f"{AMapService.BASE_URL}/place/around"
        params = {
            "key": AMapService.API_KEY,
            "location": f"{lng},{lat}",
            "types": "050000|060000|080000|200300",
            "radius": radius,
            "offset": 20,
            "page": 1,
            "output": "JSON"
        }

        try:
            client = AMapService._get_client()
            response = await client.get(url, params=params)
            if response.status_code == 200:
                data = response.json()
                if data.get("status") == "1":
                    count = int(data.get("count", 0))
                    pois = data.get("pois", [])
                    return {
                        "success": True,
                        "count": count,
                        "top_brands": [poi["name"] for poi in pois[:3]]
                    }
                else:
                    logger.error(f"AMAP API Error: {data.get('info')}")
        except Exception as e:
            logger.error(f"AMAP Request failed: {e}")

        return {"success": False, "count": 0, "top_brands": []}

    @staticmethod
    async def get_driving_route(o_lat: float, o_lng: float, d_lat: float, d_lng: float) -> dict:
        """
        高德驾车路径规划 V3 API。
        返回真实驾车距离(km)、耗时(min)、路线折线坐标序列。
        """
        url = f"{AMapService.BASE_URL}/direction/driving"
        params = {
            "key": AMapService.API_KEY,
            "origin": f"{o_lng},{o_lat}",
            "destination": f"{d_lng},{d_lat}",
            "strategy": 10,
            "output": "JSON"
        }

        try:
            client = AMapService._get_client()
            response = await client.get(url, params=params)
            if response.status_code == 200:
                data = response.json()
                if data.get("status") == "1" and data.get("route"):
                    path_obj = data["route"]["paths"][0]
                    distance_m = int(path_obj["distance"])
                    duration_s = int(path_obj["duration"])

                    polyline_points = []
                    steps_raw = path_obj.get("steps", [])
                    for step in steps_raw:
                        raw = step.get("polyline", "")
                        for pair in raw.split(";"):
                            parts = pair.split(",")
                            if len(parts) == 2:
                                polyline_points.append([float(parts[1]), float(parts[0])])

                    return {
                        "success": True,
                        "distance_km": round(distance_m / 1000, 2),
                        "duration_min": max(1, duration_s // 60),
                        "polyline": polyline_points,
                        "steps": steps_raw,
                    }
                else:
                    logger.error(f"AMap Direction Error: {data.get('info')}")
        except Exception as e:
            logger.error(f"AMap Route Request failed: {e}")

        return {"success": False, "distance_km": 0, "duration_min": 0, "polyline": [], "steps": []}
