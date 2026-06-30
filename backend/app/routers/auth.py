from fastapi import APIRouter, BackgroundTasks, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_session
from ..email import send_admin_notification, send_verification_email
from ..errors import app_error
from ..models import User, UserStatus
from ..schemas import (
    LoginIn,
    RefreshIn,
    RegisterIn,
    RegisterOut,
    TokenOut,
    UserOut,
)
from ..security import (
    REFRESH,
    create_access_token,
    create_refresh_token,
    create_verify_token,
    decode_token,
    get_current_user,
    get_user_by_email,
    hash_password,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=RegisterOut, status_code=201)
async def register(
    body: RegisterIn,
    background: BackgroundTasks,
    session: AsyncSession = Depends(get_session),
):
    existing = await get_user_by_email(session, body.email)
    if existing is not None:
        raise app_error(409, "EMAIL_EXISTS", "该邮箱已注册")

    user = User(
        email=body.email,
        password_hash=hash_password(body.password),
        display_name=body.display_name or body.email.split("@")[0],
        status=UserStatus.pending,
        email_verified=False,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)

    # Send emails after the response is returned. smtplib is blocking and the
    # SMTP server can hang on the TLS handshake; doing it inline would stall the
    # request past the client timeout and spin the register button forever.
    background.add_task(
        send_verification_email, user.email, create_verify_token(user.id)
    )
    background.add_task(send_admin_notification, user.email)

    return RegisterOut(
        message="注册成功，请查收验证邮件，并等待管理员审批。",
        user=UserOut.model_validate(user),
    )


@router.get("/verify-email", response_class=HTMLResponse)
async def verify_email(token: str, session: AsyncSession = Depends(get_session)):
    user_id = decode_token(token, "verify")
    user = await session.get(User, user_id)
    if user is None:
        raise app_error(404, "USER_NOT_FOUND", "用户不存在")
    if not user.email_verified:
        user.email_verified = True
        await session.commit()
    return HTMLResponse(
        "<html><body style='font-family:sans-serif;text-align:center;"
        "padding-top:60px'><h2>邮箱验证成功 ✅</h2>"
        "<p>请等待管理员审批，审批通过后即可登录 PathPocket。</p>"
        "</body></html>"
    )


@router.post("/login", response_model=TokenOut)
async def login(body: LoginIn, session: AsyncSession = Depends(get_session)):
    user = await get_user_by_email(session, body.email)
    if user is None or not verify_password(body.password, user.password_hash):
        raise app_error(401, "INVALID_CREDENTIALS", "邮箱或密码错误")
    if not user.email_verified:
        raise app_error(403, "EMAIL_NOT_VERIFIED", "请先完成邮箱验证")
    if user.status == UserStatus.pending:
        raise app_error(403, "PENDING_APPROVAL", "账号正在等待管理员审批")
    if user.status == UserStatus.rejected:
        raise app_error(403, "REJECTED", "账号审批未通过，请联系管理员")

    return TokenOut(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        user=UserOut.model_validate(user),
    )


@router.post("/refresh", response_model=TokenOut)
async def refresh(body: RefreshIn, session: AsyncSession = Depends(get_session)):
    user_id = decode_token(body.refresh_token, REFRESH)
    user = await session.get(User, user_id)
    if user is None:
        raise app_error(401, "INVALID_TOKEN", "用户不存在")
    if user.status != UserStatus.approved:
        raise app_error(403, "PENDING_APPROVAL", "账号不可用")
    return TokenOut(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        user=UserOut.model_validate(user),
    )


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_user)):
    return UserOut.model_validate(user)
