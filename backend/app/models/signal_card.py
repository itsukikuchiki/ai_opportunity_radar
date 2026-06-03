from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class SignalCard(Base):
    __tablename__ = "signal_cards"

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
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
