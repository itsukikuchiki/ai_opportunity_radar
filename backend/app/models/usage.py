from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class UsageCounter(Base):
    __tablename__ = "usage_counters"
    __table_args__ = (
        Index(
            "uq_usage_counters_user_feature_period",
            "user_id",
            "feature_key",
            "period_type",
            "period_start",
            unique=True,
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    feature_key: Mapped[str] = mapped_column(String)
    period_type: Mapped[str] = mapped_column(String)
    period_start: Mapped[str] = mapped_column(String)
    count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    token_input: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    token_output: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    token_cached_input: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    model_used: Mapped[str | None] = mapped_column(String)
    source_event_id: Mapped[str | None] = mapped_column(String, index=True)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class ModelUsageLog(Base):
    __tablename__ = "model_usage_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    feature_key: Mapped[str] = mapped_column(String, index=True)
    model_used: Mapped[str | None] = mapped_column(String, index=True)
    parser_version: Mapped[str | None] = mapped_column(String)
    prompt_version: Mapped[str | None] = mapped_column(String)
    input_tokens: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    cached_input_tokens: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    latency_ms: Mapped[int | None] = mapped_column(Integer)
    fallback_used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    quota_decision: Mapped[str] = mapped_column(String, default="allowed", nullable=False)
    cache_hit: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    source_event_id: Mapped[str | None] = mapped_column(String, index=True)
    metadata_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    estimated_cost_usd: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True,
    )


class QuotaGateEvent(Base):
    __tablename__ = "quota_gate_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    feature_key: Mapped[str] = mapped_column(String, index=True)
    entitlement: Mapped[str] = mapped_column(String, default="free", nullable=False)
    period_type: Mapped[str] = mapped_column(String, nullable=False)
    period_start: Mapped[str] = mapped_column(String, nullable=False)
    limit_value: Mapped[int | None] = mapped_column(Integer)
    used_value: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    decision: Mapped[str] = mapped_column(String, index=True)
    source_event_id: Mapped[str | None] = mapped_column(String, index=True)
    metadata_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True,
    )
