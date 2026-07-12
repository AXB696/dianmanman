from fastapi import APIRouter
from datetime import datetime
from app.schemas.request import SearchRequest
from app.schemas.response import BaseResponse
from app.repositories.station_repo import station_repo
from app.services.ranking import calculate_score, is_valley_hour
from app.services.battery import BatteryService
from app.services.weather import WeatherService
from app.services.amap import AMapService
from app.services.cache import recommend_cache
import asyncio

router = APIRouter()

# Bounding box 预过滤常量
_BOX_LAT_DELTA = 0.45
_BOX_LNG_DELTA = 0.52

# 两阶段快筛阈值
_TOP_FOR_ROUTE = 5    # 第一阶段直线距离快筛后，取 Top-N 并发请求高德真实路线
_TOP_FINAL = 20       # 最终返回数量


async def _fetch_real_route(user_lat: float, user_lng: float, station: dict) -> dict:
    """获取电站真实路线距离，同时返回折线坐标用于前端导航"""
    s_lat = station["location"]["lat"]
    s_lng = station["location"]["lng"]

    route = await AMapService.get_driving_route(user_lat, user_lng, s_lat, s_lng)

    if route["success"]:
        return {"station_id": station["station_id"], **route}

    # Fallback: haversine × 1.35
    distance = station_repo.haversine_distance(user_lat, user_lng, s_lat, s_lng)
    road_distance = distance * 1.35
    return {
        "station_id": station["station_id"],
        "success": False,
        "distance_km": round(road_distance, 2),
        "duration_min": max(1, int(road_distance / 35 * 60)),
        "polyline": [],
        "steps": [],
    }


async def _enrich_amenities(rec):
    """补充周边生态指数"""
    station = rec["station"]
    lat = station["location"]["lat"]
    lng = station["location"]["lng"]

    amenity_data = await AMapService.get_amenities_around(lat, lng)

    if amenity_data["success"] and amenity_data["count"] > 0:
        count = amenity_data["count"]
        bonus_score = min(10.0, count * 0.5)
        rec["score"] = round(rec["score"] + bonus_score, 2)

        brands = "、".join(amenity_data["top_brands"])
        amenity_insight = f"🛍️ 周边{count}家店 ({brands})"
        if rec["insight"]:
            rec["insight"] += f" | {amenity_insight}"
        else:
            rec["insight"] = amenity_insight

    return rec


@router.post("/recommend", response_model=BaseResponse)
async def recommend_stations(request: SearchRequest):
    user_lat = request.user_location.lat
    user_lng = request.user_location.lng
    max_dist = request.max_distance or 100.0

    # ========== 缓存查询：TTL 60s，同一位置/参数直接返回 ==========
    cache_key_data = {
        "user_lat": user_lat,
        "user_lng": user_lng,
        "current_soc": request.current_soc,
        "target_soc": request.target_soc,
        "battery_capacity": request.battery_capacity,
        "energy_consumption": request.energy_consumption,
        "district_filter": request.district_filter,
        "type_filter": request.type_filter,
        "max_distance": max_dist,
    }
    cached = await recommend_cache.get(cache_key_data)
    if cached is not None:
        return BaseResponse(data=cached)

    # ========== 阶段1: district + type + bounding box 快速初筛 ==========
    filtered = station_repo.get_all()
    if request.district_filter or request.type_filter:
        filtered = [
            s for s in filtered
            if (not request.district_filter or s.get("district_group") in request.district_filter)
            and (not request.type_filter or s.get("type") in request.type_filter)
        ]

    current_temp = await WeatherService.get_current_temperature_async(user_lat, user_lng)
    now = datetime.now()

    lat_min = user_lat - _BOX_LAT_DELTA
    lat_max = user_lat + _BOX_LAT_DELTA
    lng_min = user_lng - _BOX_LNG_DELTA
    lng_max = user_lng + _BOX_LNG_DELTA

    # 初筛候选：直线距离快筛
    candidates = []
    for station in filtered:
        s_lat = station["location"]["lat"]
        s_lng = station["location"]["lng"]

        if not (lat_min <= s_lat <= lat_max and lng_min <= s_lng <= lng_max):
            continue

        straight_dist = station_repo.haversine_distance(user_lat, user_lng, s_lat, s_lng)
        if straight_dist > max_dist:
            continue

        # 用直线距离×1.35 做第一阶段粗估路线
        est_road = straight_dist * 1.35
        est_duration = max(1, int(est_road / 35 * 60))

        candidates.append({
            "station": station,
            "straight_dist": straight_dist,
            "est_road_km": est_road,
            "est_duration_min": est_duration,
        })

    # ========== 阶段2: 对 Top-N 并发请求高德真实路线 ==========
    # 按预估路线距离排序，取 Top-N 并发请求
    candidates.sort(key=lambda x: x["est_road_km"])
    top_candidates = candidates[:_TOP_FOR_ROUTE]

    route_tasks = [
        _fetch_real_route(user_lat, user_lng, c["station"])
        for c in top_candidates
    ]
    route_results = await asyncio.gather(*route_tasks)

    # 构建 station_id → route 的映射
    route_map = {r["station_id"]: r for r in route_results}

    # ========== 阶段3: 综合评分（使用真实路线距离） ==========
    recommendations = []
    for c in candidates:
        station = c["station"]
        sid = station["station_id"]

        # 真实路线：来自 route_map；Fallback：用第一阶段粗估值
        if sid in route_map:
            route = route_map[sid]
            road_distance = route["distance_km"]
            duration = route["duration_min"]
            polyline = route["polyline"]
            steps = route["steps"]
        else:
            road_distance = c["est_road_km"]
            duration = c["est_duration_min"]
            polyline = []
            steps = []

        arrive_hour = (now.hour + duration // 60) % 24

        reachable = BatteryService.can_reach(
            request.current_soc,
            request.battery_capacity,
            request.energy_consumption,
            road_distance,
            temperature_c=current_temp
        )

        charging_time = BatteryService.estimate_charging_time(
            request.current_soc, request.target_soc, request.battery_capacity,
            station.get("power_kw", 60), station.get("type")
        )

        price_info = BatteryService.estimate_cost(
            station, request.battery_capacity, request.target_soc,
            request.current_soc, arrive_duration_mins=duration
        )

        parking_fee_per_hour = station.get("price", {}).get("parking_fee", 0) or 0
        wait_time = station.get("availability", {}).get("wait_time", 0) or 0

        score_result = calculate_score(
            station=station,
            distance_km=road_distance,
            wait_time_min=wait_time,
            preference=request.preference,
            dynamic_unit_price=price_info["unit_price"],
            charging_time_min=charging_time,
            arrival_hour=arrive_hour,
            parking_fee_per_hour=parking_fee_per_hour,
        )

        score = score_result["score"]
        bd = score_result["breakdown"]
        bonus = score_result["bonus"]
        penalty = score_result["penalty"]

        # 洞察消息
        insight_parts = []
        if price_info["insight"]:
            insight_parts.append(price_info["insight"])

        degradation = BatteryService.get_thermal_degradation(current_temp)
        if degradation > 1.0:
            insight_parts.append(f"⚠️ {current_temp}°C 能耗+{int((degradation-1)*100)}%")

        if bd["S_wait"] < 30 and wait_time > 0:
            insight_parts.append(f"⚠️ 等桩{wait_time}min")
        if bd["S_price"] < 30:
            insight_parts.append(f"💰 电价偏高({price_info['unit_price']:.2f}元)")
        if is_valley_hour(arrive_hour) and price_info["unit_price"] < 0.5:
            insight_parts.append("🌙 谷时低价")

        insight_msg = " | ".join(insight_parts) if insight_parts else ""

        recommendations.append({
            "station": station,
            "score": score,
            "distance": round(road_distance, 2),
            "duration": max(duration, 1),
            "estimated_charging_time": charging_time,
            "estimated_cost": price_info["cost"],
            "insight": insight_msg,
            "reachable": reachable,
            "route": {
                "distance": round(road_distance, 2),
                "duration": max(duration, 1),
                "path": polyline,
                "method": "amap_route" if polyline else "haversine_fallback",
                "steps": steps,
            },
            "_score_detail": {
                "S_dist": bd["S_dist"],
                "S_price": bd["S_price"],
                "S_wait": bd["S_wait"],
                "S_power": bd["S_power"],
                "S_fatigue": bd["S_fatigue"],
                "S_parking": bd["S_parking"],
                "S_avail": bd["S_avail"],
                "bonus": bonus,
                "penalty": penalty,
            }
        })

    # ========== 排序: 优先可达，再按评分 ==========
    recommendations.sort(key=lambda x: (-x["reachable"], -x["score"]))

    # ========== 阶段4: 前5名补充周边生态（并发） ==========
    top5 = recommendations[:5]
    enriched_top5 = await asyncio.gather(*(_enrich_amenities(rec) for rec in top5))
    enriched_top5.sort(key=lambda x: (-x["reachable"], -x["score"]))
    recommendations[:5] = enriched_top5

    result_data = {
        "total": len(filtered),
        "recommendations": recommendations[:_TOP_FINAL]
    }
    await recommend_cache.set(cache_key_data, result_data)

    return BaseResponse(data=result_data)
