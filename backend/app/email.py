import smtplib
from email.message import EmailMessage

from .config import get_settings

_settings = get_settings()


def _verification_link(token: str) -> str:
    return f"{_settings.backend_base_url}/auth/verify-email?token={token}"


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
