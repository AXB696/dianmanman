"""
API: /api/v1/admin
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import get_db
from app.core.dependencies import get_current_admin
from app.models.user import User
from app.models.vehicle import Vehicle
from app.models.favorite import Favorite
from app.models.history import History
from app.models.user import User as UserModel

router = APIRouter()


@router.get("/stats")
def get_stats(_: UserModel = Depends(get_current_admin), db: Session = Depends(get_db)):
    user_count = db.query(func.count(User.id)).scalar()
    vehicle_count = db.query(func.count(Vehicle.id)).scalar()
    favorite_count = db.query(func.count(Favorite.id)).scalar()
    history_count = db.query(func.count(History.id)).scalar()

    return {
        "user_count": user_count,
        "vehicle_count": vehicle_count,
        "favorite_count": favorite_count,
        "history_count": history_count,
    }
