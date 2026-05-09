from fastapi import APIRouter, HTTPException
from typing import List, Dict
from app.repositories.vehicle_repo import vehicle_repo
from app.schemas.response import BaseResponse

router = APIRouter()

@router.get("/vehicles", response_model=BaseResponse)
async def get_vehicle_brands():
    brands = vehicle_repo.get_all_brands()
    return BaseResponse(data={"brands": brands})

@router.get("/vehicles/{brand}", response_model=BaseResponse)
async def get_vehicle_models(brand: str):
    models_dict = vehicle_repo.get_models_by_brand(brand)
    if models_dict is None:
        raise HTTPException(status_code=404, detail="品牌不存在")
    
    models_list = []
    for model_name, specs in models_dict.items():
        models_list.append({
            "name": model_name,
            "battery_kwh": specs["battery"],
            "consumption_kwh_100km": specs["consumption"],
            "max_charge_power_kw": specs["max_charge_power"],
            "battery_type": specs["battery_type"]
        })
        
    return BaseResponse(data={"brand": brand, "models": models_list})

@router.get("/vehicle/{brand}/{model}", response_model=BaseResponse)
async def get_vehicle_specs(brand: str, model: str):
    specs = vehicle_repo.get_vehicle_specs(brand, model)
    if specs is None:
        raise HTTPException(status_code=404, detail="车型或品牌不存在")
        
    return BaseResponse(data={
        "brand": brand,
        "model": model,
        "battery_kwh": specs["battery"],
        "consumption_kwh_100km": specs["consumption"],
        "max_charge_power_kw": specs["max_charge_power"],
        "battery_type": specs["battery_type"],
        "estimated_range_km": round(specs["battery"] / specs["consumption"] * 100, 1)
    })
