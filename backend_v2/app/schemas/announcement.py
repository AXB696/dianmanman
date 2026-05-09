"""
Pydantic 模型：Announcement（站内公告）
"""
from datetime import datetime
from pydantic import BaseModel, Field


class AnnouncementCreate(BaseModel):
    title: str = Field(..., max_length=50)
    content: str = Field(..., max_length=500)
    status: str = Field(default="draft")  # draft / published


class AnnouncementUpdate(BaseModel):
    title: str | None = Field(default=None, max_length=50)
    content: str | None = Field(default=None, max_length=500)
    status: str | None = Field(default=None)  # draft / published


class AnnouncementResponse(BaseModel):
    id: int
    title: str
    content: str
    status: str
    created_at: str | None
    updated_at: str | None
