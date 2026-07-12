"""
API: /api/v1/auth
"""
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import (
    verify_password,
    get_password_hash,
    create_tokens,
    decode_token,
    TokenPayload,
)
from app.core.exceptions import BusinessException
from app.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, RefreshRequest, TokenResponse

router = APIRouter()


@router.post("/register", response_model=TokenResponse)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    # 检查用户名唯一
    existing = db.query(User).filter(User.username == req.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="用户名已存在")

    # 创建用户（默认普通用户 role=user）
    user = User(
        username=req.username,
        password_hash=get_password_hash(req.password),
        nickname=req.nickname or req.username,
        phone=req.phone,
        role="user",
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return create_tokens(user.id, user.role)


@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == req.username).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="用户名或密码错误")

    # 更新最近登录时间
    user.last_login_at = datetime.utcnow()
    db.commit()

    return create_tokens(user.id, user.role)


@router.post("/refresh", response_model=TokenResponse)
def refresh(req: RefreshRequest, db: Session = Depends(get_db)):
    payload = decode_token(req.refresh_token)
    if not payload or payload.type != "refresh":
        raise HTTPException(status_code=401, detail="无效的 Refresh Token")

    user = db.query(User).filter(User.id == int(payload.sub)).first()
    if not user:
        raise HTTPException(status_code=401, detail="用户不存在")

    return create_tokens(user.id, user.role)
