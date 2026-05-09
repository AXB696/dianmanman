"""
API: /api/v1/admin/announcements/* — 公告管理（需 admin 权限）
API: /api/v1/announcements/latest   — App端获取最新公告（需登录）
"""
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_current_admin
from app.models.announcement import Announcement
from app.models.user import User
from app.schemas.announcement import (
    AnnouncementCreate,
    AnnouncementUpdate,
    AnnouncementResponse,
)

router = APIRouter()
public_router = APIRouter()


class PaginatedAnnouncements(BaseModel):
    total: int
    announcements: list[AnnouncementResponse]


# ── Admin: 公告 CRUD ───────────────────────────────────

@router.get("/announcements", response_model=PaginatedAnnouncements)
def list_announcements(
    offset: int = 0,
    limit: int = 20,
    _: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    total = db.query(Announcement).count()
    items = (
        db.query(Announcement)
        .order_by(Announcement.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return PaginatedAnnouncements(
        total=total,
        announcements=[_to_resp(a) for a in items],
    )


@router.post("/announcements", response_model=AnnouncementResponse)
def create_announcement(
    req: AnnouncementCreate,
    _: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    ann = Announcement(
        title=req.title,
        content=req.content,
        status=req.status or "draft",
    )
    db.add(ann)
    db.commit()
    db.refresh(ann)
    return _to_resp(ann)


@router.put("/announcements/{ann_id}", response_model=AnnouncementResponse)
def update_announcement(
    ann_id: int,
    req: AnnouncementUpdate,
    _: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    ann = db.query(Announcement).filter(Announcement.id == ann_id).first()
    if not ann:
        raise HTTPException(status_code=404, detail="公告不存在")
    if req.title is not None:
        ann.title = req.title
    if req.content is not None:
        ann.content = req.content
    if req.status is not None:
        ann.status = req.status
    db.commit()
    db.refresh(ann)
    return _to_resp(ann)


@router.delete("/announcements/{ann_id}")
def delete_announcement(
    ann_id: int,
    _: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    ann = db.query(Announcement).filter(Announcement.id == ann_id).first()
    if not ann:
        raise HTTPException(status_code=404, detail="公告不存在")
    db.delete(ann)
    db.commit()
    return {"message": "删除成功"}


# ── Public: App端最新公告 ───────────────────────────────

@public_router.get("/announcements/latest")
def latest_announcements(
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """App端获取最近7天内已发布的公告（需登录）"""
    cutoff = datetime.utcnow() - timedelta(days=7)
    items = (
        db.query(Announcement)
        .filter(
            Announcement.status == "published",
            Announcement.created_at >= cutoff,
        )
        .order_by(Announcement.created_at.desc())
        .limit(10)
        .all()
    )
    return {
        "announcements": [_to_resp(a) for a in items],
    }


def _to_resp(a: Announcement) -> AnnouncementResponse:
    return AnnouncementResponse(
        id=a.id,
        title=a.title,
        content=a.content,
        status=a.status,
        created_at=a.created_at.isoformat() if a.created_at else None,
        updated_at=a.updated_at.isoformat() if a.updated_at else None,
    )
