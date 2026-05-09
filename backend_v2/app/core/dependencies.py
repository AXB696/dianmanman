"""
FastAPI 依赖：JWT 鉴权 / 获取当前用户
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decode_token, TokenPayload
from app.models.user import User

security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    token = credentials.credentials
    payload = decode_token(token)

    if not payload or payload.type != "access":
        raise HTTPException(status_code=401, detail="无效或过期的 Token")

    if payload.sub is None:
        raise HTTPException(status_code=401, detail="Token 解析失败")

    user = db.query(User).filter(User.id == int(payload.sub)).first()
    if not user:
        raise HTTPException(status_code=401, detail="用户不存在")

    return user


def get_current_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role not in ("admin", "super_admin"):
        raise HTTPException(status_code=403, detail="需要管理员权限")
    return current_user


def get_current_super_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "super_admin":
        raise HTTPException(status_code=403, detail="需要超级管理员权限")
    return current_user
