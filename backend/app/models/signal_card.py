from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class SignalCard(Base):
    __tablename__ = "signal_cards"
    __table_args__ = (
        Index(
            "uq_signal_cards_user_client_id",
            "user_id",
            "client_id",
            unique=True,
            postgresql_where=text("client_id IS NOT NULL"),
        ),
        Index("idx_signal_cards_server_id", "server_id"),
        Index(
            "ix_signal_cards_user_period_weekly",
            "user_id",
            "local_date",
            "included_in_weekly",
            "created_at",
        ),
        Index(
            "ix_signal_cards_user_period_journey",
            "user_id",
            "local_date",
            "included_in_journey",
            "created_at",
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    capture_id: Mapped[str | None] = mapped_column(
        ForeignKey("captures.id", ondelete="SET NULL"),
        index=True,
    )
    raw_memory_id: Mapped[str | None] = mapped_column(
        ForeignKey("raw_memories.id", ondelete="SET NULL"),
        index=True,
    )
    source_type: Mapped[str] = mapped_column(String, index=True)
    client_id: Mapped[str | None] = mapped_column(String)
    server_id: Mapped[str | None] = mapped_column(String)
    raw_text: Mapped[str] = mapped_column(Text, default="", nullable=False)
    raw_payload_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    ai_reply: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), index=True)
    local_date: Mapped[object] = mapped_column(Date, index=True)
    timezone: Mapped[str] = mapped_column(String, default="UTC", nullable=False)
    language: Mapped[str] = mapped_column(String, default="en", nullable=False)
    emotion: Mapped[str | None] = mapped_column(String)
    intensity: Mapped[int | None] = mapped_column(Integer)
    scene: Mapped[str | None] = mapped_column(String)
    friction: Mapped[str | None] = mapped_column(String)
    positive_signal: Mapped[str | None] = mapped_column(String)
    energy_load: Mapped[str | None] = mapped_column(String)
    linked_life_chain_stage: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    confidence_score: Mapped[float | None] = mapped_column(Float)
    user_confirmation: Mapped[str] = mapped_column(
        String,
        default="unconfirmed",
        nullable=False,
    )
    user_correction_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    included_in_summary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    included_in_weekly: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    included_in_journey: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    linked_experiment_id: Mapped[str | None] = mapped_column(String, index=True)
    parser_version: Mapped[str] = mapped_column(String, default="v3_rules_1", nullable=False)
    model_used: Mapped[str | None] = mapped_column(String)
    prompt_version: Mapped[str | None] = mapped_column(String)
    token_usage_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    privacy_level: Mapped[str] = mapped_column(String, default="private", nullable=False)
    schema_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_legacy: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    migration_status: Mapped[str] = mapped_column(String, default="native", nullable=False)
    metadata_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    deleted_at: Mapped[object | None] = mapped_column(DateTime(timezone=True), index=True)
    deletion_reason: Mapped[str | None] = mapped_column(String)
    tombstone_version: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    restored_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class SignalProcessingState(Base):
    __tablename__ = "signal_processing_state"
    __table_args__ = (
        Index("ix_signal_processing_state_sync_status", "sync_status"),
        Index(
            "ix_signal_processing_state_stages",
            "daily_status",
            "weekly_status",
            "journey_status",
        ),
    )

    signal_id: Mapped[str] = mapped_column(
        ForeignKey("signal_cards.id", ondelete="CASCADE"),
        primary_key=True,
    )
    sync_status: Mapped[str] = mapped_column(String, default="synced", nullable=False)
    assist_status: Mapped[str] = mapped_column(String, default="not_started", nullable=False)
    reason_status: Mapped[str] = mapped_column(String, default="not_started", nullable=False)
    daily_status: Mapped[str] = mapped_column(String, default="not_started", nullable=False)
    weekly_status: Mapped[str] = mapped_column(String, default="not_started", nullable=False)
    journey_status: Mapped[str] = mapped_column(String, default="not_started", nullable=False)
    last_processed_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    retry_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    processing_version: Mapped[str] = mapped_column(
        String,
        default="v4_p0_02",
        nullable=False,
    )
    last_error: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class SignalAnalysisPolicy(Base):
    __tablename__ = "signal_analysis_policy"
    __table_args__ = (
        Index("ix_signal_analysis_policy_privacy", "privacy_level"),
        Index(
            "ix_signal_analysis_policy_flags",
            "inaccurate",
            "do_not_analyze",
            "is_sensitive",
            "is_excluded",
        ),
    )

    signal_id: Mapped[str] = mapped_column(
        ForeignKey("signal_cards.id", ondelete="CASCADE"),
        primary_key=True,
    )
    privacy_level: Mapped[str] = mapped_column(String, default="private", nullable=False)
    is_sensitive: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_excluded: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    do_not_analyze: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    requires_user_confirmation: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    confirmed_by_user: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    inaccurate: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    exclusion_reason: Mapped[str | None] = mapped_column(String)
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
