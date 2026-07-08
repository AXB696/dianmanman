"""
ORM 模型：History
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from app.core.database import Base


class History(Base):
    __tablename__ = "history"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    station_id = Column(String(50), nullable=False, index=True)
    station_name = Column(String(200), default="")  # 站点名称
    visited_at = Column(DateTime, default=datetime.utcnow)
    duration_min = Column(Integer, default=0)  # 充电时长（分钟）
    cost_yuan = Column(Float, default=0.0)     # 充电花费（元）
    energy_kwh = Column(Float, default=0.0)    # 充入电量（度）

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "station_id": self.station_id,
            "station_name": self.station_name or "",
            "visited_at": self.visited_at.isoformat() if self.visited_at else None,
            "duration_min": self.duration_min or 0,
            "cost_yuan": round(self.cost_yuan or 0, 2),
            "energy_kwh": round(self.energy_kwh or 0, 2),
        }
