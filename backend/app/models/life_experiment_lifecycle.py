from sqlalchemy import Date, DateTime, ForeignKey, Index, Integer, String, Text, desc, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class LifeExperimentLifecycleEvent(Base):
    __tablename__ = "life_experiment_lifecycle_events"
    __table_args__ = (
        Index(
            "idx_life_experiment_events_exp",
            "experiment_id",
            desc("event_date"),
        ),
        Index(
            "idx_life_experiment_events_user_date",
            "user_id",
            desc("local_date"),
        ),
        Index(
            "idx_life_experiment_events_user_period",
            "user_id",
            "local_date",
            "event_type",
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    experiment_id: Mapped[str] = mapped_column(String)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    event_type: Mapped[str] = mapped_column(String, nullable=False)
    event_date: Mapped[object] = mapped_column(DateTime(timezone=True))
    local_date: Mapped[object] = mapped_column(Date)
    source_type: Mapped[str | None] = mapped_column(String)
    source_id: Mapped[str | None] = mapped_column(String)
    status_from: Mapped[str | None] = mapped_column(String)
    status_to: Mapped[str | None] = mapped_column(String)
    payload: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class LifeExperimentRollup(Base):
    __tablename__ = "life_experiment_rollups"
    __table_args__ = (
        Index(
            "idx_life_experiment_rollups_user_week",
            "user_id",
            desc("source_week_start"),
        ),
        Index(
            "idx_life_experiment_rollups_root",
            "root_experiment_id",
            desc("source_week_start"),
        ),
        Index(
            "idx_life_experiment_rollups_user_period",
            "user_id",
            "source_week_start",
            "source_week_end",
            desc("updated_at"),
        ),
    )

    experiment_id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    root_experiment_id: Mapped[str] = mapped_column(String)
    parent_experiment_id: Mapped[str | None] = mapped_column(String)
    source_week_start: Mapped[object] = mapped_column(Date)
    source_week_end: Mapped[object] = mapped_column(Date)
    current_status: Mapped[str] = mapped_column(String, nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    hypothesis: Mapped[str] = mapped_column(Text, nullable=False)
    suggested_action: Mapped[str] = mapped_column(Text, nullable=False)
    total_feedback_count: Mapped[int] = mapped_column(Integer, default=0)
    tried_count: Mapped[int] = mapped_column(Integer, default=0)
    helpful_count: Mapped[int] = mapped_column(Integer, default=0)
    not_helpful_count: Mapped[int] = mapped_column(Integer, default=0)
    adjusted_count: Mapped[int] = mapped_column(Integer, default=0)
    skipped_count: Mapped[int] = mapped_column(Integer, default=0)
    active_week_count: Mapped[int] = mapped_column(Integer, default=1)
    first_started_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    last_feedback_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    last_event_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    lineage: Mapped[list[dict]] = mapped_column(JsonType, default=list, nullable=False)
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
