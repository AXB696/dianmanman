"""
API: /api/v1/favorites
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.favorite import Favorite
from app.schemas.favorite import FavoriteAdd, FavoriteResponse

router = APIRouter()


@router.get("", response_model=list[FavoriteResponse])
def list_favorites(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    favorites = (
        db.query(Favorite)
        .filter(Favorite.user_id == current_user.id)
        .order_by(Favorite.created_at.desc())
        .all()
    )
    return [
        FavoriteResponse(
            id=f.id,
            user_id=f.user_id,
            station_id=f.station_id,
            created_at=f.created_at.isoformat() if f.created_at else None,
        )
        for f in favorites
    ]


@router.post("", response_model=FavoriteResponse)
def add_favorite(
    req: FavoriteAdd,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # 检查是否已存在（去重）
    existing = (
        db.query(Favorite)
        .filter(Favorite.user_id == current_user.id, Favorite.station_id == req.station_id)
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="已收藏过该站点")

    try:
        fav = Favorite(user_id=current_user.id, station_id=req.station_id)
        db.add(fav)
        db.commit()
        db.refresh(fav)
        return FavoriteResponse(
            id=fav.id,
            user_id=fav.user_id,
            station_id=fav.station_id,
            created_at=fav.created_at.isoformat() if fav.created_at else None,
        )
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="已收藏过该站点")


@router.delete("/{station_id}")
def delete_favorite(
    station_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    fav = (
        db.query(Favorite)
        .filter(Favorite.user_id == current_user.id, Favorite.station_id == station_id)
        .first()
    )
    if not fav:
        raise HTTPException(status_code=404, detail="收藏不存在")
    db.delete(fav)
    db.commit()
    return {"message": "取消收藏成功"}
