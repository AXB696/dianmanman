"""
API: /api/v1/admin/users/* — 管理员账号管理
  GET    /admin/users           — 管理员列表（仅 super_admin 可看所有 admin）
  POST   /admin/users           — 新增管理员（仅 super_admin）
  PUT    /admin/users/{id}/password — 修改管理员密码（本人或 super_admin）
  DELETE /admin/users/{id}     — 删除管理员（仅 super_admin，不可删自己/不可删super_admin）
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field

from app.core.database import get_db
from app.core.dependencies import get_current_admin, get_current_super_admin
from app.core.security import get_password_hash
from app.models.user import User
from app.schemas.user import UserProfile

router = APIRouter()


class AdminUserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6, max_length=128)
    nickname: str = Field(default="", max_length=100)
    phone: str = Field(default="", max_length=20)
    role: str = Field(default="admin")  # admin 或 super_admin


class PasswordUpdate(BaseModel):
    new_password: str = Field(..., min_length=6, max_length=128)


class PaginatedAdminUsers(BaseModel):
    total: int
    users: list[UserProfile]


# ── 管理员列表 ─────────────────────────────────────────

@router.get("/users", response_model=PaginatedAdminUsers)
def list_admin_users(
    _: User = Depends(get_current_super_admin),
    db: Session = Depends(get_db),
):
    """获取所有 admin/super_admin 账号列表（仅 super_admin 可访问）"""
    admins = (
        db.query(User)
        .filter(User.role.in_(["admin", "super_admin"]))
        .order_by(User.id.asc())
        .all()
    )
    return PaginatedAdminUsers(
        total=len(admins),
        users=[
            UserProfile(
                id=u.id,
                username=u.username,
                nickname=u.nickname,
                phone=u.phone,
                avatar_url=u.avatar_url,
                role=u.role,
                created_at=u.created_at.isoformat() if u.created_at else None,
            )
            for u in admins
        ],
    )


# ── 新增管理员 ─────────────────────────────────────────

@router.post("/users", response_model=UserProfile)
def create_admin_user(
    req: AdminUserCreate,
    _: User = Depends(get_current_super_admin),
    db: Session = Depends(get_db),
):
    """新增管理员账号（仅 super_admin）"""
    # 检查用户名唯一
    existing = db.query(User).filter(User.username == req.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="用户名已存在")

    if req.role not in ("admin", "super_admin"):
        raise HTTPException(status_code=400, detail="role 必须是 admin 或 super_admin")

    user = User(
        username=req.username,
        password_hash=get_password_hash(req.password),
        nickname=req.nickname or req.username,
        phone=req.phone,
        role=req.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return UserProfile(
        id=user.id,
        username=user.username,
        nickname=user.nickname,
        phone=user.phone,
        avatar_url=user.avatar_url,
        role=user.role,
        created_at=user.created_at.isoformat() if user.created_at else None,
    )


# ── 修改管理员密码 ─────────────────────────────────────

@router.put("/users/{user_id}/password")
def update_admin_password(
    user_id: int,
    req: PasswordUpdate,
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """修改管理员密码（本人或 super_admin 可操作）"""
    # 仅本人或 super_admin 可修改
    if current_user.id != user_id and current_user.role != "super_admin":
        raise HTTPException(status_code=403, detail="无权限操作")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    if user.role not in ("admin", "super_admin"):
        raise HTTPException(status_code=400, detail="只能修改管理员账号")

    user.password_hash = get_password_hash(req.new_password)
    db.commit()
    return {"message": "密码修改成功"}


# ── 删除管理员 ─────────────────────────────────────────

@router.delete("/users/{user_id}")
def delete_admin_user(
    user_id: int,
    current_user: User = Depends(get_current_super_admin),
    db: Session = Depends(get_db),
):
    """删除管理员账号（仅 super_admin，不可删自己，不可删 super_admin）"""
    if current_user.id == user_id:
        raise HTTPException(status_code=400, detail="不可删除自己")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    if user.role == "super_admin":
        raise HTTPException(status_code=400, detail="不可删除超级管理员")

    if user.role not in ("admin", "super_admin"):
        raise HTTPException(status_code=400, detail="只能删除管理员账号")

    db.delete(user)
    db.commit()
    return {"message": "删除成功"}
