import smtplib
from email.message import EmailMessage

from .config import get_settings

_settings = get_settings()


def _verification_link(token: str) -> str:
    return f"{_settings.backend_base_url}/auth/verify-email?token={token}"


def send_admin_notification(new_user_email: str) -> None:
    """Notifies the admin that a new user is waiting for approval."""
    admin_email = _settings.admin_email
    review_url = f"{_settings.backend_base_url}/docs#/admin/list_users_admin_users_get"

    if not _settings.smtp_host:
        print(
            f"[email] new registration from {new_user_email} — notify admin {admin_email}",
            flush=True,
        )
        return

    msg = EmailMessage()
    msg["Subject"] = f"[PathPocket] 新用户注册待审批：{new_user_email}"
    msg["From"] = _settings.smtp_from
    msg["To"] = admin_email
    msg.set_content(
        f"有新用户注册了 PathPocket，请及时审批。\n\n"
        f"注册邮箱：{new_user_email}\n\n"
        f"请登录管理面板审批：{review_url}\n"
    )

    with smtplib.SMTP(_settings.smtp_host, _settings.smtp_port) as smtp:
        smtp.starttls()
        if _settings.smtp_user:
            smtp.login(_settings.smtp_user, _settings.smtp_password)
        smtp.send_message(msg)


def send_verification_email(to_email: str, token: str) -> None:
    """Sends the verification link, or prints it when SMTP is not configured.

    Dev mode (no SMTP_HOST) just logs the link to the console so you can click
    it without a real mail server.
    """
    link = _verification_link(token)

    if not _settings.smtp_host:
        print(f"[email] verification link for {to_email}: {link}", flush=True)
        return

    msg = EmailMessage()
    msg["Subject"] = "PathPocket 邮箱验证"
    msg["From"] = _settings.smtp_from
    msg["To"] = to_email
    msg.set_content(
        "欢迎注册 PathPocket。\n\n"
        f"请点击以下链接验证邮箱：\n{link}\n\n"
        "验证后还需等待管理员审批，审批通过即可登录。"
    )

    with smtplib.SMTP(_settings.smtp_host, _settings.smtp_port) as smtp:
        smtp.starttls()
        if _settings.smtp_user:
            smtp.login(_settings.smtp_user, _settings.smtp_password)
        smtp.send_message(msg)
