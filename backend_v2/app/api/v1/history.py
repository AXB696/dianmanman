"""
API: /api/v1/history
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.history import History
from app.schemas.history import HistoryAdd, HistoryRecord

router = APIRouter()


@router.get("", response_model=list[HistoryRecord])
def list_history(
    offset: int = 0,
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    history = (
        db.query(History)
        .filter(History.user_id == current_user.id)
        .order_by(History.visited_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return [
        HistoryRecord(
            id=h.id,
            user_id=h.user_id,
            station_id=h.station_id,
            station_name=h.station_name or "",
            visited_at=h.visited_at.isoformat() if h.visited_at else None,
        )
        for h in history
    ]


@router.post("", response_model=HistoryRecord)
def add_history(
    req: HistoryAdd,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = History(
        user_id=current_user.id,
        station_id=req.station_id,
        station_name=req.station_name or "",
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return HistoryRecord(
        id=record.id,
        user_id=record.user_id,
        station_id=record.station_id,
        station_name=record.station_name or "",
        visited_at=record.visited_at.isoformat() if record.visited_at else None,
    )


@router.delete("/{history_id}")
def delete_history(
    history_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = (
        db.query(History)
        .filter(History.id == history_id, History.user_id == current_user.id)
        .first()
    )
    if not record:
        raise HTTPException(status_code=404, detail="记录不存在")
    db.delete(record)
    db.commit()
    return {"message": "删除成功"}
