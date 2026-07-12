import json
import os
import math
import asyncio
from typing import List, Dict, Optional

class StationRepository:
    def __init__(self):
        self._data: List[Dict] = []
        self._index: Dict[str, Dict] = {}
        self._ready = False

    async def load_data_async(self):
        """异步加载数据，避免阻塞事件循环"""
        file_path = os.path.join(os.path.dirname(__file__), "stations_data.json")
        try:
            # 使用线程池避免阻塞（在事件循环外运行 CPU/IO 密集任务）
            def _load():
                with open(file_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            self._data = await asyncio.get_event_loop().run_in_executor(None, _load)
            self._index = {s["station_id"]: s for s in self._data if s.get("station_id")}
            self._ready = True
            print(f"Station data loaded: {len(self._data)} stations")
        except Exception as e:
            print(f"Error loading station data: {e}")

    def load_data(self):
        """同步版本（保留向后兼容，startup 使用）"""
        file_path = os.path.join(os.path.dirname(__file__), "stations_data.json")
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                self._data = json.load(f)
                self._index = {s["station_id"]: s for s in self._data if s.get("station_id")}
                self._ready = True
        except Exception as e:
            print(f"Error loading station data: {e}")

    def get_all(self, offset: int = 0, limit: int = 0) -> List[Dict]:
        """返回数据，支持分页。limit=0 表示返回全部"""
        if limit <= 0:
            return self._data[offset:]
        return self._data[offset:offset + limit]

    def get_by_id(self, station_id: str) -> Optional[Dict]:
        return self._index.get(station_id)

    def filter_stations(
        self,
        district: Optional[str] = None,
        station_type: Optional[str] = None,
        offset: int = 0,
        limit: int = 0,
    ) -> List[Dict]:
        """单次遍历完成 district + type 过滤，支持分页"""
        results = [
            s for s in self._data
            if (not district or s.get("district_group") == district)
            and (not station_type or s.get("type") == station_type)
        ]
        if limit <= 0:
            return results[offset:]
        return results[offset:offset + limit]

    def count_all(self) -> int:
        return len(self._data)

    @staticmethod
    def haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        R = 6371  # 地球半径(km)
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        dlat = math.radians(lat2 - lat1)
        dlng = math.radians(lng2 - lng1)
        a = math.sin(dlat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlng / 2) ** 2
        return R * (2 * math.asin(math.sqrt(a)))

station_repo = StationRepository()
