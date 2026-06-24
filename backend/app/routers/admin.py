from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_session
from ..errors import app_error
from ..models import User, UserStatus
from ..schemas import UserOut
from ..security import require_admin

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_admin)])


@router.get("/users", response_model=list[UserOut])
async def list_users(
    status: UserStatus | None = None,
    session: AsyncSession = Depends(get_session),
):
    stmt = select(User).order_by(User.created_at.desc())
    if status is not None:
        stmt = stmt.where(User.status == status)
    result = await session.execute(stmt)
    return [UserOut.model_validate(u) for u in result.scalars().all()]


@router.post("/users/{user_id}/approve", response_model=UserOut)
async def approve_user(user_id: str, session: AsyncSession = Depends(get_session)):
    user = await session.get(User, user_id)
    if user is None:
        raise app_error(404, "USER_NOT_FOUND", "用户不存在")
    user.status = UserStatus.approved
    user.approved_at = datetime.now(timezone.utc)
    await session.commit()
    await session.refresh(user)
    return UserOut.model_validate(user)


@router.post("/users/{user_id}/reject", response_model=UserOut)
async def reject_user(user_id: str, session: AsyncSession = Depends(get_session)):
    user = await session.get(User, user_id)
    if user is None:
        raise app_error(404, "USER_NOT_FOUND", "用户不存在")
    user.status = UserStatus.rejected
    await session.commit()
    await session.refresh(user)
    return UserOut.model_validate(user)
