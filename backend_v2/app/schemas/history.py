"""
Pydantic 模型：History 相关
"""
from pydantic import BaseModel


class HistoryAdd(BaseModel):
    station_id: str
    station_name: str = ""
    duration_min: int = 0
    cost_yuan: float = 0.0
    energy_kwh: float = 0.0


class HistoryRecord(BaseModel):
    id: int
    user_id: int
    station_id: str
    station_name: str = ""
    visited_at: str | None = None
    duration_min: int = 0
    cost_yuan: float = 0.0
    energy_kwh: float = 0.0

    class Config:
        from_attributes = True
