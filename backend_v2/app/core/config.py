import secrets
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "Smart Charge API v2"
    API_V1_STR: str = "/api/v1"

    # 高德地图 API Key（必须通过环境变量或 .env 文件配置）
    AMAP_KEY: str = ""

    # JWT 签名密钥（生产环境务必修改，默认值仅用于开发）
    JWT_SECRET_KEY: str = ""

    # JWT 过期时间（天）
    JWT_ACCESS_EXPIRE_DAYS: int = 7
    JWT_REFRESH_EXPIRE_DAYS: int = 30

    class Config:
        env_file = ".env"
        case_sensitive = True

    def get_jwt_secret(self) -> str:
        """获取 JWT 密钥，若未配置则生成随机密钥（每次重启会变化，仅开发用）"""
        if self.JWT_SECRET_KEY:
            return self.JWT_SECRET_KEY
        # 开发环境自动生成随机密钥
        import warnings
        warnings.warn(
            "JWT_SECRET_KEY 未配置！已使用随机密钥（服务重启后所有 token 将失效）。"
            "请在 .env 文件中设置 JWT_SECRET_KEY。",
            RuntimeWarning
        )
        return secrets.token_hex(32)


settings = Settings()
