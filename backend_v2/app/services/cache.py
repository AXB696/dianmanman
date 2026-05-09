"""
推荐结果缓存服务：减少高德 API 调用次数
基于请求参数哈希 + TTL 过期
"""
import asyncio
import hashlib
import time
from dataclasses import dataclass, field
from typing import Any, Optional


@dataclass
class CacheEntry:
    data: Any
    expire_at: float   # 绝对时间戳（秒）


class RecommendCache:
    """
    LRU-like 推荐结果缓存。
    缓存 key = 请求参数哈希，TTL 内直接返回缓存。
    """
    def __init__(self, ttl_seconds: float = 60.0, max_entries: int = 200):
        self._cache: dict[str, CacheEntry] = {}
        self._ttl = ttl_seconds
        self._max_entries = max_entries
        self._lock = asyncio.Lock()

    def _make_key(self, request_data: dict) -> str:
        """将请求参数字典转为稳定哈希字符串"""
        # 按固定字段顺序序列化，保证同一请求生成相同 key
        stable = {
            "lat": round(request_data.get("user_lat", 0), 4),
            "lng": round(request_data.get("user_lng", 0), 4),
            "soc": request_data.get("current_soc", 50),
            "target_soc": request_data.get("target_soc", 80),
            "capacity": request_data.get("battery_capacity", 60),
            "consumption": request_data.get("energy_consumption", 15),
            "district": tuple(sorted(request_data.get("district_filter") or [])),
            "type": tuple(sorted(request_data.get("type_filter") or [])),
            "max_dist": request_data.get("max_distance", 100),
        }
        raw = str(sorted(stable.items())).encode()
        return hashlib.md5(raw, usedforsecurity=False).hexdigest()

    async def get(self, request_data: dict) -> Optional[Any]:
        """TTL 内返回缓存数据，否则返回 None"""
        key = self._make_key(request_data)
        async with self._lock:
            entry = self._cache.get(key)
            if entry is None:
                return None
            if time.monotonic() > entry.expire_at:
                # 已过期，删除
                self._cache.pop(key, None)
                return None
            return entry.data

    async def set(self, request_data: dict, data: Any):
        """写入缓存"""
        key = self._make_key(request_data)
        async with self._lock:
            # 超过最大容量时，清理最老的 20% 条目
            if len(self._cache) >= self._max_entries:
                # 按过期时间排序，删掉最早过期的
                sorted_keys = sorted(
                    self._cache.keys(),
                    key=lambda k: self._cache[k].expire_at
                )
                for k in sorted_keys[:int(self._max_entries * 0.2)]:
                    self._cache.pop(k, None)

            self._cache[key] = CacheEntry(
                data=data,
                expire_at=time.monotonic() + self._ttl
            )

    async def clear(self):
        """清空所有缓存（关闭时调用）"""
        async with self._lock:
            self._cache.clear()

    def stats(self) -> dict:
        """返回缓存统计（调试用）"""
        now = time.monotonic()
        active = sum(1 for e in self._cache.values() if e.expire_at > now)
        return {
            "total_entries": len(self._cache),
            "active_entries": active,
            "ttl_seconds": self._ttl,
            "max_entries": self._max_entries,
        }


# 全局单例
recommend_cache = RecommendCache(ttl_seconds=60.0, max_entries=200)
