from pydantic import BaseModel, Field
from typing import Optional, List

class Location(BaseModel):
    lat: float
    lng: float
    address: Optional[str] = ""

class UserPreference(BaseModel):
    distance_weight: float = Field(default=0.3, ge=0, le=1)
    price_weight: float = Field(default=0.3, ge=0, le=1)
    wait_time_weight: float = Field(default=0.2, ge=0, le=1)
    power_weight: float = Field(default=0.2, ge=0, le=1)
    prefer_ultra: bool = Field(default=False)

class SearchRequest(BaseModel):
    user_location: Location
    dest_location: Optional[Location] = None
    current_soc: float = Field(default=50, ge=0, le=100)
    target_soc: float = Field(default=80, ge=0, le=100)
    battery_capacity: float = Field(default=60, ge=0)
    energy_consumption: float = Field(default=15, ge=0)
    preference: UserPreference = Field(default_factory=UserPreference)
    district_filter: Optional[List[str]] = None
    type_filter: Optional[List[str]] = None
    max_distance: Optional[float] = None
