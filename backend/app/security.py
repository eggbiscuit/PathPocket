from datetime import datetime, timedelta, timezone

from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .config import get_settings
from .database import get_session
from .errors import app_error
from .models import User, UserRole

_settings = get_settings()
_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login", auto_error=False)

# JWT `typ` claim values, to stop a refresh/verify token being used as access.
ACCESS = "access"
REFRESH = "refresh"
VERIFY = "verify"


def hash_password(password: str) -> str:
    return _pwd.hash(password)


def verify_password(password: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False
    return _pwd.verify(password, password_hash)


def _encode(sub: str, typ: str, expires: timedelta) -> str:
    now = datetime.now(timezone.utc)
    payload = {"sub": sub, "typ": typ, "iat": now, "exp": now + expires}
    return jwt.encode(payload, _settings.jwt_secret, algorithm=_settings.jwt_algorithm)


def create_access_token(user_id: str) -> str:
    return _encode(
        user_id, ACCESS, timedelta(minutes=_settings.access_token_expire_minutes)
    )


def create_refresh_token(user_id: str) -> str:
    return _encode(
        user_id, REFRESH, timedelta(days=_settings.refresh_token_expire_days)
    )


def create_verify_token(user_id: str) -> str:
    return _encode(
        user_id, VERIFY, timedelta(hours=_settings.verify_token_expire_hours)
    )


def decode_token(token: str, expected_typ: str) -> str:
    """Returns the subject (user id) if the token is valid and of the right type."""
    try:
        payload = jwt.decode(
            token, _settings.jwt_secret, algorithms=[_settings.jwt_algorithm]
        )
    except JWTError:
        raise app_error(401, "INVALID_TOKEN", "登录状态无效或已过期，请重新登录")
    if payload.get("typ") != expected_typ:
        raise app_error(401, "INVALID_TOKEN", "令牌类型不匹配")
    sub = payload.get("sub")
    if not sub:
        raise app_error(401, "INVALID_TOKEN", "令牌缺少用户标识")
    return sub


async def get_current_user(
    token: str | None = Depends(oauth2_scheme),
    session: AsyncSession = Depends(get_session),
) -> User:
    if not token:
        raise app_error(401, "NOT_AUTHENTICATED", "请先登录")
    user_id = decode_token(token, ACCESS)
    user = await session.get(User, user_id)
    if user is None:
        raise app_error(401, "INVALID_TOKEN", "用户不存在")
    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != UserRole.admin:
        raise app_error(403, "FORBIDDEN", "需要管理员权限")
    return user


async def get_user_by_email(session: AsyncSession, email: str) -> User | None:
    result = await session.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()
