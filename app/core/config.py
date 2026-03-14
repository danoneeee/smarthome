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
    max_devices_per_user: int = 50
    mqtt_host: str | None = None
    mqtt_port: int = 1883
    mqtt_username: str | None = None
    mqtt_password: str | None = None
    mqtt_topic_prefix: str = "smarthome"

    @property
    def mqtt_enabled(self) -> bool:
        return bool(self.mqtt_host and self.mqtt_host.strip())

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
