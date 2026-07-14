from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class ExperimentCandidate(Base):
    __tablename__ = "experiment_candidates"
    __table_args__ = (
        Index(
            "idx_experiment_candidates_source",
            "source_type",
            "source_id",
            "user_id",
        ),
        Index(
            "idx_experiment_candidates_week",
            "user_id",
            "source_week_start",
            "status",
        ),
        Index("idx_experiment_candidates_adopted", "adopted_experiment_id"),
        Index(
            "idx_experiment_candidates_stale",
            "user_id",
            "source_week_start",
            "dirty",
            "is_stale",
            "status",
        ),
        Index(
            "idx_experiment_candidates_group",
            "candidate_group_id",
            "candidate_rank",
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    source_type: Mapped[str] = mapped_column(String, nullable=False)
    source_id: Mapped[str] = mapped_column(String, nullable=False)
    source_week_start: Mapped[object] = mapped_column(Date)
    source_week_end: Mapped[object] = mapped_column(Date)
    title: Mapped[str] = mapped_column(String, nullable=False)
    hypothesis: Mapped[str] = mapped_column(Text, nullable=False)
    suggested_action: Mapped[str] = mapped_column(Text, nullable=False)
    linked_signal_card_ids: Mapped[list[str]] = mapped_column(
        JsonType,
        default=list,
        nullable=False,
    )
    linked_observation_ids: Mapped[list[str]] = mapped_column(
        JsonType,
        default=list,
        nullable=False,
    )
    status: Mapped[str] = mapped_column(String, default="generated")
    confidence_level: Mapped[str] = mapped_column(
        String,
        default="medium",
        nullable=False,
    )
    metadata_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    adopted_experiment_id: Mapped[str | None] = mapped_column(String)
    candidate_group_id: Mapped[str | None] = mapped_column(String)
    candidate_rank: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    source_hash: Mapped[str | None] = mapped_column(String)
    dirty: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_stale: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    stale_reason: Mapped[str | None] = mapped_column(Text)
    invalidated_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
