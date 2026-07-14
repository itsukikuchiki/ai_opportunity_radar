from sqlalchemy import Date, DateTime, Float, ForeignKey, Index, String, Text, desc, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Observation(Base):
    __tablename__ = "observations"
    __table_args__ = (
        Index(
            "idx_observations_user_status_date",
            "user_id",
            "status",
            "source_period_start",
            desc("updated_at"),
        ),
        Index("idx_observations_ai_judgement", "source_ai_judgement_id"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    observation_text: Mapped[str] = mapped_column(Text, nullable=False)
    observation_type: Mapped[str] = mapped_column(
        String,
        default="hypothesis",
        nullable=False,
    )
    confidence: Mapped[str] = mapped_column(String, default="medium", nullable=False)
    status: Mapped[str] = mapped_column(String, default="generated")
    source_period_start: Mapped[object | None] = mapped_column(Date)
    source_period_end: Mapped[object | None] = mapped_column(Date)
    created_by: Mapped[str] = mapped_column(
        String,
        default="l2_reason",
        nullable=False,
    )
    source_ai_judgement_id: Mapped[str | None] = mapped_column(String)
    evidence_text: Mapped[str | None] = mapped_column(Text)
    suggested_pattern: Mapped[str | None] = mapped_column(String)
    suggested_life_chain_stage: Mapped[str | None] = mapped_column(String)
    user_adjustment_text: Mapped[str | None] = mapped_column(Text)
    confirmation_note: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
    confirmed_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    dismissed_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    archived_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))


class ObservationSignalLink(Base):
    __tablename__ = "observation_signal_links"
    __table_args__ = (
        Index("idx_observation_signal_links_signal", "signal_id"),
    )

    observation_id: Mapped[str] = mapped_column(
        ForeignKey("observations.id", ondelete="CASCADE"),
        primary_key=True,
    )
    signal_id: Mapped[str] = mapped_column(
        ForeignKey("signal_cards.id", ondelete="CASCADE"),
        primary_key=True,
    )
    weight: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    reason: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
