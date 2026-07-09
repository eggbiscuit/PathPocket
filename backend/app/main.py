import logging
import os
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

logger = logging.getLogger("pathpocket")

from .config import get_settings
from .database import SessionLocal, create_all
from .models import User, UserRole, UserStatus
from .routers import admin, auth, wsi
from .security import get_user_by_email, hash_password

settings = get_settings()


async def _seed_admin() -> None:
    """Ensures the configured admin exists and is fully usable."""
    async with SessionLocal() as session:
        existing = await get_user_by_email(session, settings.admin_email)
        if existing is None:
            session.add(
                User(
                    email=settings.admin_email,
                    password_hash=hash_password(settings.admin_password),
                    display_name="管理员",
                    role=UserRole.admin,
                    status=UserStatus.approved,
                    email_verified=True,
                    approved_at=datetime.now(timezone.utc),
                )
            )
        else:
            existing.role = UserRole.admin
            existing.status = UserStatus.approved
            existing.email_verified = True
            # Make ADMIN_PASSWORD authoritative even when the admin email was
            # already a registered user, so the .env password always works.
            existing.password_hash = hash_password(settings.admin_password)
        await session.commit()


@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.jwt_secret_is_default:
        logger.warning(
            "JWT_SECRET is still the default value — set a strong secret "
            "(`openssl rand -hex 32`) before deploying to production."
        )
    await create_all()
    await _seed_admin()
    os.makedirs(settings.wsi_storage_dir, exist_ok=True)
    yield


app = FastAPI(title="PathPocket API", version="0.1.0", lifespan=lifespan)

# CORS is fully env-driven: list the allowed origins in CORS_ORIGINS, and set
# CORS_ORIGIN_REGEX for dynamic origins (e.g. ngrok subdomains). Never combine
# allow_origins=["*"] with allow_credentials=True — the two are incompatible.
_cors: dict = {
    "allow_origins": settings.cors_origin_list,
    "allow_credentials": True,
    "allow_methods": ["*"],
    "allow_headers": ["*"],
    # WSI tiles carry an Authorization header, so each tile URL triggers a
    # preflight OPTIONS. Cache preflights to cut per-tile latency.
    "max_age": 3600,
}
if settings.cors_origin_regex:
    _cors["allow_origin_regex"] = settings.cors_origin_regex
app.add_middleware(CORSMiddleware, **_cors)

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(wsi.router)


@app.get("/health", tags=["meta"])
async def health():
    return {"status": "ok"}
