import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import BigInteger, Boolean, DateTime, Enum, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class UserRole(str, enum.Enum):
    user = "user"
    admin = "admin"


class UserStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class SlideStatus(str, enum.Enum):
    uploading = "uploading"  # bytes still streaming to disk
    ready = "ready"          # OpenSlide opened OK, previewable
    failed = "failed"        # unreadable / unsupported


def _uuid() -> str:
    return f"u_{uuid.uuid4().hex}"


def _slide_uuid() -> str:
    return f"s_{uuid.uuid4().hex}"


def _now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    # Nullable so third-party (e.g. WeChat) accounts without a password fit later.
    password_hash: Mapped[str | None] = mapped_column(String, nullable=True)
    display_name: Mapped[str | None] = mapped_column(String, nullable=True)

    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole), default=UserRole.user, nullable=False
    )
    status: Mapped[UserStatus] = mapped_column(
        Enum(UserStatus), default=UserStatus.pending, nullable=False
    )
    email_verified: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    # Reserved for future third-party providers; "email" for now.
    provider: Mapped[str] = mapped_column(String, default="email", nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, nullable=False
    )
    approved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class Slide(Base):
    __tablename__ = "slides"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_slide_uuid)
    user_id: Mapped[str] = mapped_column(
        String, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    original_filename: Mapped[str] = mapped_column(String, nullable=False)
    stored_path: Mapped[str] = mapped_column(String, nullable=False)
    # OpenSlide's detected vendor format, e.g. "aperio" / "generic-tiff".
    fmt: Mapped[str] = mapped_column(String, nullable=False)
    file_size: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    status: Mapped[SlideStatus] = mapped_column(
        Enum(SlideStatus), default=SlideStatus.uploading, nullable=False
    )
    # Level-0 pixel dimensions, cached so the list/viewer needn't reopen the slide.
    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, nullable=False
    )
