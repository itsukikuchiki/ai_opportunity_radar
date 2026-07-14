from sqlalchemy import Date, DateTime, Float, ForeignKey, Index, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class AnalyticsEvent(Base):
    __tablename__ = "analytics_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    event_name: Mapped[str] = mapped_column(String, index=True)
    event_date: Mapped[object] = mapped_column(Date, index=True)
    properties_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    numeric_value: Mapped[float | None] = mapped_column(Float)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True,
    )


class UserSubscription(Base):
    __tablename__ = "user_subscriptions"

    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    product_id: Mapped[str | None] = mapped_column(String, index=True)
    status: Mapped[str] = mapped_column(String, default="inactive", nullable=False)
    environment: Mapped[str | None] = mapped_column(String)
    reason: Mapped[str | None] = mapped_column(Text)
    transaction_date: Mapped[str | None] = mapped_column(String)
    latest_verified_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class AiUsage(Base):
    __tablename__ = "ai_usage"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    endpoint: Mapped[str] = mapped_column(String, index=True)
    estimated_input_tokens: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    estimated_output_tokens: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    estimated_cost_usd: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True,
    )


class LegacyEndpointTelemetry(Base):
    __tablename__ = "legacy_endpoint_telemetry"
    __table_args__ = (
        Index("idx_legacy_endpoint_counter", "counter_name", "created_at"),
        Index("idx_legacy_endpoint_endpoint", "endpoint", "created_at"),
        Index("idx_legacy_endpoint_user_hash", "user_id_hash"),
        Index("idx_legacy_endpoint_account_hash", "account_id_hash"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    counter_name: Mapped[str] = mapped_column(String)
    endpoint: Mapped[str] = mapped_column(String)
    client_version: Mapped[str | None] = mapped_column(String)
    platform: Mapped[str | None] = mapped_column(String)
    user_id_hash: Mapped[str | None] = mapped_column(String)
    account_id_hash: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
