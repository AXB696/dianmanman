"""
API: /api/v1/users
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_current_admin
from app.models.user import User
from app.models.vehicle import Vehicle
from app.schemas.user import UserProfile, UserUpdate
from app.schemas.vehicle import VehicleCreate, VehicleUpdate, VehicleResponse

router = APIRouter()


class PaginatedUsers(BaseModel):
    total: int
    users: list[UserProfile]


# ── 用户车辆 CRUD (/users/me/vehicles/*) ─────────────────────

@router.get("/me/vehicles", response_model=list[VehicleResponse])
def list_my_vehicles(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    vehicles = (
        db.query(Vehicle)
        .filter(Vehicle.user_id == current_user.id)
        .order_by(Vehicle.is_default.desc(), Vehicle.created_at.desc())
        .all()
    )
    return [
        VehicleResponse(
            id=v.id, user_id=v.user_id, brand=v.brand, model=v.model,
            battery_capacity=v.battery_capacity, energy_consumption=v.energy_consumption,
            is_default=bool(v.is_default),
            created_at=v.created_at.isoformat() if v.created_at else None,
        )
        for v in vehicles
    ]


@router.post("/me/vehicles", response_model=VehicleResponse)
def add_my_vehicle(
    req: VehicleCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if req.is_default:
        db.query(Vehicle).filter(Vehicle.user_id == current_user.id).update({"is_default": 0})
    vehicle = Vehicle(
        user_id=current_user.id, brand=req.brand, model=req.model,
        battery_capacity=req.battery_capacity, energy_consumption=req.energy_consumption,
        is_default=1 if req.is_default else 0,
    )
    db.add(vehicle)
    db.commit()
    db.refresh(vehicle)
    return VehicleResponse(
        id=vehicle.id, user_id=vehicle.user_id, brand=vehicle.brand, model=vehicle.model,
        battery_capacity=vehicle.battery_capacity, energy_consumption=vehicle.energy_consumption,
        is_default=bool(vehicle.is_default),
        created_at=vehicle.created_at.isoformat() if vehicle.created_at else None,
    )


@router.put("/me/vehicles/{vehicle_id}", response_model=VehicleResponse)
def update_my_vehicle(
    vehicle_id: int,
    req: VehicleUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    vehicle = (
        db.query(Vehicle)
        .filter(Vehicle.id == vehicle_id, Vehicle.user_id == current_user.id)
        .first()
    )
    if not vehicle:
        raise HTTPException(status_code=404, detail="车辆不存在")
    if req.is_default:
        db.query(Vehicle).filter(Vehicle.user_id == current_user.id).update({"is_default": 0})
    if req.brand is not None:
        vehicle.brand = req.brand
    if req.model is not None:
        vehicle.model = req.model
    if req.battery_capacity is not None:
        vehicle.battery_capacity = req.battery_capacity
    if req.energy_consumption is not None:
        vehicle.energy_consumption = req.energy_consumption
    if req.is_default is not None:
        vehicle.is_default = 1 if req.is_default else 0
    db.commit()
    db.refresh(vehicle)
    return VehicleResponse(
        id=vehicle.id, user_id=vehicle.user_id, brand=vehicle.brand, model=vehicle.model,
        battery_capacity=vehicle.battery_capacity, energy_consumption=vehicle.energy_consumption,
        is_default=bool(vehicle.is_default),
        created_at=vehicle.created_at.isoformat() if vehicle.created_at else None,
    )


@router.get("/{user_id}/vehicles", response_model=list[VehicleResponse])
def list_user_vehicles(
    user_id: int,
    _: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Admin获取指定用户的车辆列表"""
    vehicles = (
        db.query(Vehicle)
        .filter(Vehicle.user_id == user_id)
        .order_by(Vehicle.is_default.desc(), Vehicle.created_at.desc())
        .all()
    )
    return [
        VehicleResponse(
            id=v.id, user_id=v.user_id, brand=v.brand, model=v.model,
            battery_capacity=v.battery_capacity, energy_consumption=v.energy_consumption,
            is_default=bool(v.is_default),
            created_at=v.created_at.isoformat() if v.created_at else None,
        )
        for v in vehicles
    ]


@router.delete("/me/vehicles/{vehicle_id}")
def delete_my_vehicle(
    vehicle_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    vehicle = (
        db.query(Vehicle)
        .filter(Vehicle.id == vehicle_id, Vehicle.user_id == current_user.id)
        .first()
    )
    if not vehicle:
        raise HTTPException(status_code=404, detail="车辆不存在")
    db.delete(vehicle)
    db.commit()
    return {"message": "删除成功"}


# ── 用户信息 ───────────────────────────────────────────────

@router.get("/me", response_model=UserProfile)
def get_me(current_user: User = Depends(get_current_user)):
    return UserProfile(
        id=current_user.id,
        username=current_user.username,
        nickname=current_user.nickname,
        phone=current_user.phone,
        avatar_url=current_user.avatar_url,
        role=current_user.role,
        created_at=current_user.created_at.isoformat() if current_user.created_at else None,
    )


@router.put("/me", response_model=UserProfile)
def update_me(
    update: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if update.nickname is not None:
        current_user.nickname = update.nickname
    if update.phone is not None:
        current_user.phone = update.phone
    if update.avatar_url is not None:
        current_user.avatar_url = update.avatar_url
    db.commit()
    db.refresh(current_user)

    return UserProfile(
        id=current_user.id,
        username=current_user.username,
        nickname=current_user.nickname,
        phone=current_user.phone,
        avatar_url=current_user.avatar_url,
        role=current_user.role,
        created_at=current_user.created_at.isoformat() if current_user.created_at else None,
    )


@router.get("", response_model=PaginatedUsers)
def list_users(
    username: str = "",
    phone: str = "",
    offset: int = 0,
    limit: int = 20,
    _: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = db.query(User)
    if username:
        q = q.filter(User.username.contains(username))
    if phone:
        q = q.filter(User.phone.contains(phone))

    total = q.count()
    users = q.order_by(User.id.desc()).offset(offset).limit(limit).all()

    return PaginatedUsers(
        total=total,
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
            for u in users
        ],
    )


@router.delete("/{user_id}")
def delete_user(
    user_id: int,
    _: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    db.delete(user)
    db.commit()
    return {"message": "删除成功"}
