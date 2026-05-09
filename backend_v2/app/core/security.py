"""
JWT 认证 + 密码哈希工具
"""
from datetime import datetime, timedelta
from typing import Optional

from jose import JWTError, jwt
import bcrypt
from pydantic import BaseModel

from app.core.config import settings

ALGORITHM = "HS256"
JWT_SECRET = JWT_SECRET  # 模块加载时解析一次，避免每次调用都触发警告
# ──────────────────────────────────────────────────────


class TokenPayload(BaseModel):
    sub: str  # user_id
    role: str = "user"
    type: str  # "access" or "refresh"


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))


def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def create_access_token(user_id: int, role: str = "user") -> str:
    expire = datetime.utcnow() + timedelta(days=settings.JWT_ACCESS_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "role": role,
        "type": "access",
        "exp": expire,
        "iat": datetime.utcnow(),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=ALGORITHM)


def create_refresh_token(user_id: int, role: str = "user") -> str:
    expire = datetime.utcnow() + timedelta(days=settings.JWT_REFRESH_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "role": role,
        "type": "refresh",
        "exp": expire,
        "iat": datetime.utcnow(),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=ALGORITHM)


def decode_token(token: str) -> Optional[TokenPayload]:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        return TokenPayload(
            sub=payload.get("sub", ""),
            role=payload.get("role", "user"),
            type=payload.get("type", "access"),
        )
    except JWTError:
        return None


def create_tokens(user_id: int, role: str = "user") -> TokenResponse:
    return TokenResponse(
        access_token=create_access_token(user_id, role),
        refresh_token=create_refresh_token(user_id, role),
    )
