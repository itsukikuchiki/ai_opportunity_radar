from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    desc,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class CandidateGroup(Base):
    __tablename__ = "candidate_groups"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "candidate_kind",
            "period_start",
            "source_hash",
            name="uq_candidate_groups_source",
        ),
        Index(
            "idx_candidate_groups_read",
            "user_id",
            "candidate_kind",
            "period_start",
            "status",
            desc("updated_at"),
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    candidate_kind: Mapped[str] = mapped_column(String, nullable=False)
    period_start: Mapped[object] = mapped_column(Date, nullable=False)
    period_end: Mapped[object] = mapped_column(Date, nullable=False)
    source_hash: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, default="ready", nullable=False)
    required_signal_count: Mapped[int] = mapped_column(Integer, default=3)
    eligible_signal_count: Mapped[int] = mapped_column(Integer, default=0)
    dirty: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_stale: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    stale_reason: Mapped[str | None] = mapped_column(Text)
    invalidated_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    generation_started_at: Mapped[object | None] = mapped_column(
        DateTime(timezone=True)
    )
    generation_finished_at: Mapped[object | None] = mapped_column(
        DateTime(timezone=True)
    )
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class MicroActionCandidate(Base):
    __tablename__ = "micro_action_candidates"
    __table_args__ = (
        CheckConstraint(
            "rank BETWEEN 1 AND 3",
            name="ck_micro_action_candidates_rank",
        ),
        Index(
            "idx_micro_action_candidates_group",
            "candidate_group_id",
            "rank",
        ),
        Index(
            "idx_micro_action_candidates_read",
            "user_id",
            "local_date",
            "status",
            "dirty",
            "is_stale",
            "rank",
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    candidate_group_id: Mapped[str] = mapped_column(String)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    local_date: Mapped[object] = mapped_column(Date, nullable=False)
    rank: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    reason: Mapped[str] = mapped_column(Text, default="", nullable=False)
    difficulty: Mapped[str] = mapped_column(
        String, default="very_light", nullable=False
    )
    linked_signal_card_ids: Mapped[list[str]] = mapped_column(
        JsonType, default=list, nullable=False
    )
    focus_domain_ids: Mapped[list[str]] = mapped_column(
        JsonType, default=list, nullable=False
    )
    status: Mapped[str] = mapped_column(String, default="generated", nullable=False)
    adopted_micro_action_id: Mapped[str | None] = mapped_column(String)
    source_hash: Mapped[str] = mapped_column(String, nullable=False)
    dirty: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_stale: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    stale_reason: Mapped[str | None] = mapped_column(Text)
    invalidated_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
