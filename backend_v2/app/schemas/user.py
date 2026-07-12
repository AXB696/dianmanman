"""
Pydantic 模型：User 相关
"""
from pydantic import BaseModel


class UserProfile(BaseModel):
    id: int
    username: str
    nickname: str | None = ""
    phone: str | None = ""
    avatar_url: str | None = ""
    role: str
    created_at: str | None = None

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    nickname: str | None = None
    phone: str | None = None
    avatar_url: str | None = None
