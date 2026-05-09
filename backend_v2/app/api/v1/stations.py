from fastapi import APIRouter, Query, Depends
from typing import Optional
from app.repositories.station_repo import station_repo
from app.schemas.response import BaseResponse
from app.core.dependencies import get_current_admin
from app.models.user import User

router = APIRouter()

@router.get("/stations", response_model=BaseResponse)
async def get_stations(
    lat: float = Query(..., description="用户纬度"),
    lng: float = Query(..., description="用户经度"),
    soc: float = Query(50, ge=0, le=100, description="当前电量"),
    target_soc: float = Query(80, ge=0, le=100, description="目标电量"),
    district: Optional[str] = Query(None, description="区域筛选"),
    station_type: Optional[str] = Query(None, description="类型筛选"),
    top_n: int = Query(10, ge=1, le=50, description="返回数量"),
    offset: int = Query(0, ge=0, description="偏移量")
):
    # 单次遍历完成 district + type 过滤，支持分页
    filtered = station_repo.filter_stations(district, station_type)

    recommendations = []

    for station in filtered:
        s_lat = station["location"]["lat"]
        s_lng = station["location"]["lng"]

        distance = station_repo.haversine_distance(lat, lng, s_lat, s_lng)
        road_distance = distance * 1.35
        duration = max(int(road_distance / 35 * 60), 1)

        recommendations.append({
            "station": station,
            "score": max(0, 100 - road_distance * 2),
            "distance": round(road_distance, 2),
            "duration": duration,
            "estimated_charging_time": 40,
            "estimated_cost": 30.5,
            "reachable": True,
            "route": {
                "distance": round(road_distance, 2),
                "duration": duration,
                "path": [],
                "method": "haversine_mock"
            }
        })

    recommendations.sort(key=lambda x: -x["score"])
    total_filtered = len(filtered)
    top_recs = recommendations[offset:offset + top_n]

    return BaseResponse(data={
        "total": total_filtered,
        "vehicle_info": {
            "battery_kwh": 60,
            "consumption_kwh_100km": 15,
            "battery_type": "三元锂",
            "estimated_range_km": 400.0
        },
        "filters": {
            "districts": ["汉口", "武昌", "汉阳"],
            "types": ["ultra", "fast", "slow", "destination", "fleet", "swap"]
        },
        "recommendations": top_recs
    })

@router.get("/station/{station_id}", response_model=BaseResponse)
async def get_station_detail(station_id: str):
    station = station_repo.get_by_id(station_id)
    if not station:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Station Not Found")
    return BaseResponse(data=station)


# ── Admin: 电站总览列表（支持筛选/搜索/排序/分页）───────────

@router.get("/admin/stations")
async def admin_list_stations(
    district: Optional[str] = Query(None, description="区域：汉口/武昌/汉阳"),
    station_type: Optional[str] = Query(None, description="类型：ultra/fast/slow/destination/fleet/swap"),
    keyword: Optional[str] = Query(None, description="搜索：电站名称/地址/运营商"),
    sort: Optional[str] = Query("name", description="排序字段：name/power_kw/rating/available"),
    order: Optional[str] = Query("asc", description="排序方向：asc/desc"),
    offset: int = Query(0, ge=0, description="偏移量"),
    limit: int = Query(20, ge=1, le=100, description="每页数量"),
    _: User = Depends(get_current_admin),
):
    """电站总览列表（仅管理员可访问），支持区域/类型/关键字筛选+排序+分页"""
    filtered = station_repo._data

    # 区域筛选
    if district:
        filtered = [s for s in filtered if s.get("district_group") == district]

    # 类型筛选
    if station_type:
        filtered = [s for s in filtered if s.get("type") == station_type]

    # 关键字搜索（名称或地址或运营商）
    if keyword:
        kw = keyword.lower()
        filtered = [
            s for s in filtered
            if kw in s.get("name", "").lower()
            or kw in s.get("address", "").lower()
            or kw in s.get("operator", "").lower()
        ]

    # 排序
    if sort in ("power_kw", "rating", "available"):
        reverse = order == "desc"
        if sort == "available":
            filtered = sorted(filtered, key=lambda s: s.get("availability", {}).get("available", 0) or 0, reverse=reverse)
        else:
            filtered = sorted(filtered, key=lambda s: s.get(sort, 0) or 0, reverse=reverse)
    else:
        # 默认按名称排序
        reverse = order == "desc"
        filtered = sorted(filtered, key=lambda s: s.get("name", ""), reverse=reverse)

    total = len(filtered)

    # 统计摘要
    ratings = [s.get("rating", 0) or 0 for s in filtered if s.get("rating")]
    avg_rating = round(sum(ratings) / len(ratings), 1) if ratings else 0.0

    page = filtered[offset:offset + limit]

    # 提取完整字段返回
    stations = []
    for s in page:
        avail = s.get("availability") or {}
        stations.append({
            "station_id": s.get("station_id"),
            "name": s.get("name"),
            "district_group": s.get("district_group"),
            "type": s.get("type"),
            "type_name": s.get("type_name") or "",
            "address": s.get("address"),
            "pile_count": s.get("pile_count"),
            "power_kw": s.get("power_kw"),
            "open_hours": s.get("open_hours"),
            "operator": s.get("operator") or "未知运营商",
            "rating": s.get("rating"),
            "availability": {
                "total": avail.get("total"),
                "available": avail.get("available"),
                "occupied": avail.get("occupied"),
            },
            "price": s.get("price"),
            "facilities": s.get("facilities") or [],
            "tel": (s.get("gaode_info") or {}).get("tel") or "",
            "lat": s.get("location", {}).get("lat"),
            "lng": s.get("location", {}).get("lng"),
        })

    return {
        "total": total,
        "districts": ["汉口", "武昌", "汉阳"],
        "types": ["ultra", "fast", "slow", "destination", "fleet", "swap"],
        "summary": {
            "total": total,
            "ultra_count": sum(1 for s in filtered if s.get("type") == "ultra"),
            "fast_count": sum(1 for s in filtered if s.get("type") == "fast"),
            "avg_rating": avg_rating,
        },
        "stations": stations,
    }
