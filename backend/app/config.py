from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "sqlite+aiosqlite:///./pathpocket.db"

    jwt_secret: str = "change-me-to-a-long-random-secret"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    # Email-verification tokens live longer so a user has time to click the link.
    verify_token_expire_hours: int = 48

    admin_email: str = "admin@pathpocket.dev"
    admin_password: str = "change-me-admin-password"

    backend_base_url: str = "http://localhost:8000"
    cors_origins: str = "http://localhost:8080,http://localhost:3000"
    # Optional regex for dynamic origins (e.g. ngrok subdomains). Empty disables it.
    cors_origin_regex: str = ""

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "PathPocket <no-reply@pathpocket.dev>"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def jwt_secret_is_default(self) -> bool:
        return self.jwt_secret == "change-me-to-a-long-random-secret"


@lru_cache
def get_settings() -> Settings:
    return Settings()
