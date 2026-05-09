from fastapi import FastAPI
from app.core.config import settings
from app.core.exceptions import (
    BusinessException,
    business_exception_handler,
    global_exception_handler
)
from app.api.v1.router import api_router
from app.repositories.station_repo import station_repo

def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.PROJECT_NAME,
        openapi_url=f"{settings.API_V1_STR}/openapi.json"
    )

    # 跨域设置
    from fastapi.middleware.cors import CORSMiddleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 注册全局异常处理器
    app.add_exception_handler(Exception, global_exception_handler)
    app.add_exception_handler(BusinessException, business_exception_handler)

    # 注册路由
    app.include_router(api_router, prefix="/api")

    # 启动时异步加载电站数据（避免阻塞事件循环）
    @app.on_event("startup")
    async def startup_event():
        from app.core.database import init_db
        init_db()
        await station_repo.load_data_async()

    # 关闭时清理连接池和缓存
    @app.on_event("shutdown")
    async def shutdown_event():
        from app.services.amap import AMapService
        from app.services.cache import recommend_cache
        await AMapService.close_client()
        await recommend_cache.clear()

    # Health Check
    @app.get("/health", tags=["System"])
    async def health_check():
        from app.schemas.response import BaseResponse
        return BaseResponse(data={"status": "ok"})

    return app

app = create_app()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
