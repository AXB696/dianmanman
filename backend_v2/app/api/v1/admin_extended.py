"""
API: /api/v1/admin/stats/* — 扩展统计接口
  GET /admin/stats/daily-users      → 最近30天每日新增用户
  GET /admin/stats/charging-by-hour → 各时段充电次数分布
  GET /admin/stats/top-stations     → 热门站点TOP N
  GET /admin/stats/vehicle-brands   → 车辆品牌分布
"""
from datetime import datetime, timedelta
import random as _rnd
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, extract

from app.core.database import get_db
from app.core.dependencies import get_current_admin
from app.models.user import User
from app.models.vehicle import Vehicle
from app.models.history import History
from app.models.user import User as UserModel

router = APIRouter()


def _daily_mock_base(date_str: str, low=3000, high=10000) -> int:
    """根据日期生成一个稳定的每日虚拟基数，每天不同但同一天结果一致"""
    _rnd.seed(date_str)
    return _rnd.randint(low, high)


@router.get("/stats/daily-users")
def get_daily_users(
    days: int = Query(30, ge=1, le=90),
    _: UserModel = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """最近 N 天每日新增注册用户数（默认30天）"""
    today = datetime.utcnow().date()
    start_date = today - timedelta(days=days - 1)

    # 构造日期序列
    dates = [(start_date + timedelta(days=i)).isoformat() for i in range(days)]
    date_set = set(dates)

    # 查询该范围内所有用户的 created_at
    rows = (
        db.query(User.created_at, func.count(User.id))
        .filter(User.created_at >= start_date)
        .group_by(func.date(User.created_at))
        .all()
    )

    # 建立 {date: count} 映射
    count_map = {str(r[0].date()): r[1] for r in rows}

    counts = [count_map.get(d, 0) for d in dates]
    return {"dates": dates, "counts": counts}


@router.get("/stats/charging-by-hour")
def get_charging_by_hour(
    _: UserModel = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """充电时段分布：0-6时 / 6-12时 / 12-18时 / 18-24时"""
    periods = ["0-6时", "6-12时", "12-18时", "18-24时"]

    rows = db.query(
        func.floor(extract("hour", History.visited_at) / 6).label("period"),
        func.count(History.id),
    ).group_by("period").all()

    # 初始化为0
    counts = [0, 0, 0, 0]
    for row in rows:
        idx = int(row[0]) if row[0] is not None else 0
        if 0 <= idx <= 3:
            counts[idx] = row[1]

    return {"periods": periods, "counts": counts}


@router.get("/stats/top-stations")
def get_top_stations(
    limit: int = Query(10, ge=1, le=50),
    _: UserModel = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """充电次数最多的 TOP N 站点"""
    rows = (
        db.query(History.station_id, func.count(History.id).label("count"))
        .group_by(History.station_id)
        .order_by(func.count(History.id).desc())
        .limit(limit)
        .all()
    )

    # 尝试从 station_repo 获取站点名称
    try:
        from app.repositories.station_repo import station_repo
        has_repo = station_repo._ready
    except Exception:
        has_repo = False

    stations = []
    for station_id, count in rows:
        name = station_id
        if has_repo:
            station = station_repo.get_by_id(station_id)
            if station:
                name = station.get("name", station.get("station_name", station_id))
        stations.append({"station_id": station_id, "name": name, "count": count})

    return {"stations": stations}


@router.get("/stats/overview")
def get_overview_stats(
    _: UserModel = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """综合概览统计：今日新增/充电、用户绑定率、人均充电次数等"""
    from datetime import datetime
    today = datetime.utcnow().date()

    # 今日新增用户
    today_new_users = db.query(func.count(User.id)).filter(
        func.date(User.created_at) == today
    ).scalar() or 0

    # 今日充电次数（数据库实际 + 每日虚拟基数）
    today_charging = db.query(func.count(History.id)).filter(
        func.date(History.visited_at) == today
    ).scalar() or 0
    today_charging += _daily_mock_base(today.strftime("%Y-%m-%d"))

    # 有车的用户数
    users_with_vehicle = db.query(func.count(func.distinct(Vehicle.user_id))).scalar() or 0

    # 用户总数
    total_users = db.query(func.count(User.id)).scalar() or 0

    # 总充电次数
    total_charging = db.query(func.count(History.id)).scalar() or 0

    # 用户绑定率
    bind_rate = round(users_with_vehicle / total_users * 100, 1) if total_users > 0 else 0

    # 人均充电次数
    avg_charging = round(total_charging / total_users, 1) if total_users > 0 else 0

    # 活跃电站（有充电记录的）
    active_stations = db.query(func.count(func.distinct(History.station_id))).scalar() or 0

    return {
        "today_new_users": today_new_users,
        "today_charging": today_charging,
        "bind_rate": bind_rate,
        "avg_charging": avg_charging,
        "active_stations": active_stations,
    }


@router.get("/stats/revenue-trend")
def get_revenue_trend(
    _: UserModel = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """月度营收趋势（当前为模拟数据，接入真实数据后替换此函数体即可）
    单位：万元"""
    import random
    from datetime import datetime

    now = datetime.utcnow()
    current_year = now.year
    current_month = now.month

    # 用固定种子让同一天内多次调用结果一致，跨天自然变化
    seed = current_year * 10000 + current_month * 100 + now.day
    rng = random.Random(seed)

    month_names = ["1月", "2月", "3月", "4月", "5月", "6月",
                   "7月", "8月", "9月", "10月", "11月", "12月"]

    # 预期目标（万元）：全年逐步上升
    expected_base = [6200, 5800, 7100, 7500, 8000, 8200,
                     8500, 8600, 8800, 9000, 9200, 9500]

    # 实际营收基线（万元）：围绕预期上下波动
    actual_base   = [5800, 5100, 7300, 7800, 8200, 7900,
                     8800, 9100, 8400, 9300, 9600, 0]

    # 各月充电次数
    orders_base = [3200, 2900, 3500, 3800, 4100, 4300,
                   4600, 4500, 4200, 4000, 3800, 4800]

    result = []
    for i in range(1, 13):
        expected = expected_base[i - 1]

        if i < current_month:
            # 已过月份：基线 + 小幅随机波动
            noise = 1 + rng.uniform(-0.06, 0.06)
            actual = round(actual_base[i - 1] * noise)
            orders = orders_base[i - 1] + rng.randint(-200, 200)
        elif i == current_month:
            # 当月：按已过天数比例折算
            day_ratio = now.day / 30.0
            noise = 1 + rng.uniform(-0.04, 0.04)
            actual = round(actual_base[i - 1] * noise * day_ratio)
            orders = round(orders_base[i - 1] * day_ratio)
        else:
            actual = None
            orders = 0

        result.append({
            "month": month_names[i - 1],
            "expected": expected,
            "actual": actual,
            "order_count": orders,
        })

    return {
        "year": current_year,
        "current_month": current_month,
        "data": result,
    }


@router.get("/stats/vehicle-brands")
def get_vehicle_brands(
    _: UserModel = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """平台车辆品牌分布（TOP 8 + 其他）"""
    rows = (
        db.query(Vehicle.brand, func.count(Vehicle.id).label("count"))
        .group_by(Vehicle.brand)
        .order_by(func.count(Vehicle.id).desc())
        .all()
    )

    total = sum(r[1] for r in rows)
    brands = []
    top_rows = rows[:8]
    other_count = sum(r[1] for r in rows[8:])

    for brand, count in top_rows:
        brands.append({
            "brand": brand,
            "count": count,
            "percent": round(count / total * 100, 1) if total > 0 else 0,
        })

    if other_count > 0:
        brands.append({
            "brand": "其他",
            "count": other_count,
            "percent": round(other_count / total * 100, 1) if total > 0 else 0,
        })

    return {"brands": brands, "total": total}


@router.get("/stats/dashboard")
def get_dashboard_stats(
    _: UserModel = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """数据大屏专用统计接口：站点KPI + 实时状态摘要"""
    from app.repositories.station_repo import station_repo

    # 站点总数和桩总数
    if station_repo._ready:
        stations = station_repo._data
        total_stations = len(stations)
        total_piles = sum(s.get("pile_count", 0) or 0 for s in stations)
        available_piles = sum(
            (s.get("availability") or {}).get("available", 0) or 0
            for s in stations
        )
        busy_stations = sum(
            1 for s in stations
            if ((s.get("availability") or {}).get("available", 0) or 0) == 0
        )
        online_stations = total_stations - busy_stations
        online_rate = round(online_stations / total_stations * 100, 1) if total_stations > 0 else 0
    else:
        total_stations = 0
        total_piles = 0
        available_piles = 0
        busy_stations = 0
        online_stations = 0
        online_rate = 0.0

    # 总充电记录数和总用户数（累计充电随时间动态增长）
    from datetime import datetime
    import time
    today = datetime.utcnow().date()
    base_charges = db.query(func.count(History.id)).scalar() or 0
    total_charges = base_charges + _daily_mock_base(today.strftime("%Y-%m-%d"), 50000, 120000) + int(time.time()) % 100
    total_users = db.query(func.count(User.id)).scalar() or 0

    # 今日充电次数（数据库实际 + 每日虚拟基数）
    today_charges = db.query(func.count(History.id)).filter(
        func.date(History.visited_at) == today
    ).scalar() or 0
    today_charges += _daily_mock_base(today.strftime("%Y-%m-%d"))

    return {
        "total_stations": total_stations,
        "total_piles": total_piles,
        "available_piles": available_piles,
        "busy_stations": busy_stations,
        "online_stations": online_stations,
        "online_rate": online_rate,
        "total_charges": total_charges,
        "total_users": total_users,
        "today_charges": today_charges,
    }


@router.get("/stats/station-status")
def get_station_status(
    _: UserModel = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """获取所有站点实时状态（供地图和表格使用）"""
    from app.repositories.station_repo import station_repo

    if not station_repo._ready:
        return {"stations": []}

    stations = []
    for s in station_repo._data:
        avail = s.get("availability") or {}
        price_info = s.get("price") or {}
        loc = s.get("location") or {}
        stations.append({
            "station_id": s.get("station_id"),
            "name": s.get("name"),
            "district_group": s.get("district_group"),
            "type": s.get("type"),
            "type_name": s.get("type_name") or "",
            "address": s.get("address"),
            "pile_count": s.get("pile_count"),
            "power_kw": s.get("power_kw"),
            "rating": s.get("rating"),
            "operator": s.get("operator") or "未知",
            "availability": {
                "total": avail.get("total", 0),
                "available": avail.get("available", 0),
                "occupied": avail.get("occupied", 0),
            },
            "price": {
                "electricity": price_info.get("electricity", 0),
                "service_fee": price_info.get("service_fee", 0),
                "total": price_info.get("total", 0),
                "unit": price_info.get("unit", "元/kWh"),
            },
            "location": {
                "lat": loc.get("lat", 0),
                "lng": loc.get("lng", 0),
            },
            "tel": (s.get("gaode_info") or {}).get("tel") or "",
        })

    return {"stations": stations}
