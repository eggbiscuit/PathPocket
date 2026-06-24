import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.database import Base, get_session
from app.main import app
from app.models import User, UserRole, UserStatus
from app.security import hash_password

ADMIN_EMAIL = "admin@test.dev"
ADMIN_PASSWORD = "admin-pass-123"


@pytest_asyncio.fixture
async def client():
    # In-memory SQLite shared across the single pooled connection.
    engine = create_async_engine(
        "sqlite+aiosqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    session_local = async_sessionmaker(engine, expire_on_commit=False)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Seed an admin directly (bypassing the app's startup seed, which is disabled
    # here by overriding the session and not running lifespan).
    async with session_local() as session:
        session.add(
            User(
                email=ADMIN_EMAIL,
                password_hash=hash_password(ADMIN_PASSWORD),
                display_name="管理员",
                role=UserRole.admin,
                status=UserStatus.approved,
                email_verified=True,
            )
        )
        await session.commit()

    async def override_get_session():
        async with session_local() as session:
            yield session

    app.dependency_overrides[get_session] = override_get_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

    app.dependency_overrides.clear()
    await engine.dispose()


async def admin_token(client) -> str:
    resp = await client.post(
        "/auth/login", json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD}
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["access_token"]
