from fastapi import APIRouter
from pydantic import BaseModel
from app.schemas.response import BaseResponse
from app.services.amap import AMapService

router = APIRouter()


class RouteRequest(BaseModel):
    origin_lat: float
    origin_lng: float
    dest_lat: float
    dest_lng: float


# 高德 action 编码转中文描述
ACTION_MAP = {
    "0": "直行",
    "1": "右转",
    "2": "左转",
    "3": "向左前方行驶",
    "4": "向右前方行驶",
    "5": "向左后方行驶",
    "6": "向右后方行驶",
    "7": "掉头",
    "8": "靠左",
    "9": "靠右",
    "10": "减速行驶",
    "11": "进入环岛",
    "12": "驶出环岛",
}


def _parse_steps(steps: list) -> list:
    """
    解析高德返回的 steps，提取导航引导信息。
    """
    nav_steps = []
    for step in steps:
        action_raw = step.get("action")
        # action 可能是字符串 "0"、列表 ["0", "1"]，或空列表 []
        if isinstance(action_raw, list) and action_raw:
            action_code = str(action_raw[0])
        elif isinstance(action_raw, str) and action_raw:
            action_code = action_raw
        else:
            action_code = "0"
        instruction = step.get("instruction", "")
        road = step.get("road", "")
        distance = int(step.get("distance", 0))
        duration = int(step.get("duration", 0))

        nav_steps.append({
            "action": ACTION_MAP.get(action_code, "直行"),
            "instruction": instruction,
            "road": road,
            "distance": distance,
            "distance_km": round(distance / 1000, 2) if distance > 0 else 0,
            "duration_sec": duration,
            "duration_min": max(1, duration // 60) if duration > 0 else 1,
        })
    return nav_steps


@router.post("/route", response_model=BaseResponse)
async def get_driving_route(req: RouteRequest):
    """
    调用高德驾车路径规划 API,
    返回真实的驾车距离、预估耗时、路线折线坐标序列，
    以及详细的导航步骤列表。
    """
    result = await AMapService.get_driving_route(
        req.origin_lat, req.origin_lng,
        req.dest_lat, req.dest_lng
    )

    if result["success"]:
        # 解析导航步骤
        nav_steps = _parse_steps(result.get("steps", []))

        return BaseResponse(data={
            "distance_km": result["distance_km"],
            "duration_min": result["duration_min"],
            "polyline": result["polyline"],  # [[lat,lng], ...]
            "steps": nav_steps,
            "strategy": "时间最短且费用最少",
        })
    else:
        return BaseResponse(code=500, message="路径规划失败", data={})
