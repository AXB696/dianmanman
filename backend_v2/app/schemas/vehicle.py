"""
Pydantic 模型：Vehicle 相关
"""
from pydantic import BaseModel


class VehicleCreate(BaseModel):
    brand: str
    model: str
    battery_capacity: float
    energy_consumption: float
    is_default: bool = False


class VehicleUpdate(BaseModel):
    brand: str | None = None
    model: str | None = None
    battery_capacity: float | None = None
    energy_consumption: float | None = None
    is_default: bool | None = None


class VehicleResponse(BaseModel):
    id: int
    user_id: int
    brand: str
    model: str
    battery_capacity: float
    energy_consumption: float
    is_default: bool
    created_at: str | None

    class Config:
        from_attributes = True
