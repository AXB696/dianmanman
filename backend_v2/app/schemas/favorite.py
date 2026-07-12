"""
Pydantic 模型：Favorite 相关
"""
from pydantic import BaseModel


class FavoriteAdd(BaseModel):
    station_id: str


class FavoriteResponse(BaseModel):
    id: int
    user_id: int
    station_id: str
    created_at: str | None

    class Config:
        from_attributes = True
