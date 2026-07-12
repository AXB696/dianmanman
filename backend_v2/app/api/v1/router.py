from fastapi import APIRouter
from app.api.v1 import stations
from app.api.v1 import vehicles
from app.api.v1 import recommend
from app.api.v1 import navigation
from app.api.v1 import auth
from app.api.v1 import users
from app.api.v1 import favorites
from app.api.v1 import history
from app.api.v1 import admin
from app.api.v1 import admin_extended
from app.api.v1 import announcements
from app.api.v1 import admin_users

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(users.router, prefix="/users", tags=["Users"])
api_router.include_router(favorites.router, prefix="/favorites", tags=["Favorites"])
api_router.include_router(history.router, prefix="/history", tags=["History"])
api_router.include_router(admin.router, prefix="/admin", tags=["Admin"])
api_router.include_router(admin_extended.router, prefix="/admin", tags=["Admin Extended"])
api_router.include_router(announcements.router, prefix="/admin", tags=["Announcements"])
api_router.include_router(admin_users.router, prefix="/admin", tags=["Admin Account"])
api_router.include_router(announcements.public_router, tags=["Announcements Public"])
api_router.include_router(stations.router, tags=["Stations"])
api_router.include_router(vehicles.router, tags=["Vehicles"])
api_router.include_router(recommend.router, tags=["Recommendation"])
api_router.include_router(navigation.router, tags=["Navigation"])
