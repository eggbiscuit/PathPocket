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

    # ASR (speech-to-text) — Aliyun Bailian / DashScope. The key stays server-side
    # only; the Flutter client streams audio through /asr/stream and never sees it.
    dashscope_api_key: str = ""
    # Switch to "fun-asr-realtime" (large-model, ~40% pricier, better term
    # robustness) by changing only this line — the SDK interface is identical.
    asr_model: str = "paraformer-realtime-v2"
    # Custom hotword vocabulary id for pathology terms. Empty disables hotwords.
    asr_vocabulary_id: str = ""

    # WSI (whole-slide image) storage + tiling.
    wsi_storage_dir: str = "/data/wsi"
    wsi_max_upload_bytes: int = 2 * 1024**3  # 2 GiB hard cap
    wsi_tile_size: int = 254  # 254 + 2*overlap = 256px effective tiles
    wsi_tile_overlap: int = 1
    wsi_cache_size: int = 6  # max concurrently-open OpenSlide handles

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def jwt_secret_is_default(self) -> bool:
        return self.jwt_secret == "change-me-to-a-long-random-secret"


@lru_cache
def get_settings() -> Settings:
    return Settings()
