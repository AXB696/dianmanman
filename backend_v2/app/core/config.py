from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Smart Charge API v2"
    API_V1_STR: str = "/api/v1"
    
    # 高德地图 API 配置 (建议从环境变量加载)
    AMAP_KEY: str = "YOUR_AMAP_KEY_HERE"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
