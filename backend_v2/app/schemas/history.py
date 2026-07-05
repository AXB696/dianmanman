"""
Pydantic 模型：History 相关
"""
from pydantic import BaseModel


class HistoryAdd(BaseModel):
    station_id: str
    station_name: str = ""


class HistoryRecord(BaseModel):
    id: int
    user_id: int
    station_id: str
    station_name: str = ""
    visited_at: str | None

    class Config:
        from_attributes = True
