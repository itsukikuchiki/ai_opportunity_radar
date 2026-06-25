from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class Account(Base):
    __tablename__ = "accounts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    apple_sub_hash: Mapped[str] = mapped_column(String, unique=True, index=True)
    session_token_hash: Mapped[str | None] = mapped_column(String, index=True)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class AccountAlias(Base):
    __tablename__ = "account_aliases"
    __table_args__ = (
        UniqueConstraint("account_id", "local_user_id", name="uq_account_local_user"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    account_id: Mapped[str] = mapped_column(
        ForeignKey("accounts.id", ondelete="CASCADE"),
        index=True,
    )
    local_user_id: Mapped[str] = mapped_column(String, index=True)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())


class BackupBundle(Base):
    __tablename__ = "backup_bundles"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    account_id: Mapped[str] = mapped_column(
        ForeignKey("accounts.id", ondelete="CASCADE"),
        index=True,
    )
    schema_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    backup_version: Mapped[str] = mapped_column(String, nullable=False)
    device_id: Mapped[str | None] = mapped_column(String, index=True)
    payload: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    counts_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    restored_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    restore_device_id: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
