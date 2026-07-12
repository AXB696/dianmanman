"""
ORM 模型：Vehicle
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from app.core.database import Base


class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    brand = Column(String(50), nullable=False)
    model = Column(String(100), nullable=False)
    battery_capacity = Column(Float, nullable=False)   # kWh
    energy_consumption = Column(Float, nullable=False)  # kWh/100km
    is_default = Column(Integer, default=0)             # 1=默认车辆
    created_at = Column(DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "brand": self.brand,
            "model": self.model,
            "battery_capacity": self.battery_capacity,
            "energy_consumption": self.energy_consumption,
            "is_default": bool(self.is_default),
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
