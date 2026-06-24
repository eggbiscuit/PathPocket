from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .database import SessionLocal, create_all
from .models import User, UserRole, UserStatus
from .routers import admin, auth
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
        await session.commit()


@asynccontextmanager
async def lifespan(app: FastAPI):
    await create_all()
    await _seed_admin()
    yield


app = FastAPI(title="PathPocket API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(admin.router)


@app.get("/health", tags=["meta"])
async def health():
    return {"status": "ok"}
