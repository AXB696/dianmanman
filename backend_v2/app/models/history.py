"""
ORM 模型：History
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from app.core.database import Base


class History(Base):
    __tablename__ = "history"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    station_id = Column(String(50), nullable=False, index=True)
    station_name = Column(String(200), default="")  # 站点名称
    visited_at = Column(DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "station_id": self.station_id,
            "station_name": self.station_name or "",
            "visited_at": self.visited_at.isoformat() if self.visited_at else None,
        }
