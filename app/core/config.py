from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "SmartHome Controller"
    debug: bool = True
    database_url: str = "sqlite+aiosqlite:///./smarthome.db"
    # JWT
    secret_key: str = "change-me-in-production-use-env"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_hours: int = 24

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
