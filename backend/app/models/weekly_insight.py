from sqlalchemy import Date, DateTime, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class WeeklyInsight(Base):
    __tablename__ = "weekly_insights"
    __table_args__ = (
        UniqueConstraint("user_id", "week_start", name="uq_weekly_user_week_start"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    week_start: Mapped[object] = mapped_column(Date)
    week_end: Mapped[object] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String, default="available", nullable=False)
    key_insight: Mapped[str | None] = mapped_column(Text)
    top_patterns_json: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    top_frictions_json: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    best_action: Mapped[str | None] = mapped_column(Text)
    opportunity_snapshot_json: Mapped[dict | None] = mapped_column(JsonType)
    chart_data_json: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    feedback_value: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
