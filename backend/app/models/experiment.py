from sqlalchemy import DateTime, ForeignKey, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from app.core.db import Base


class Experiment(Base):
    __tablename__ = "experiments"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    opportunity_id: Mapped[str] = mapped_column(ForeignKey("opportunities.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String)
    hypothesis: Mapped[str | None] = mapped_column(Text)
    action_taken: Mapped[str | None] = mapped_column(Text)
    result_summary: Mapped[str | None] = mapped_column(Text)
    feedback_score: Mapped[float | None] = mapped_column(Numeric(4, 3))
    effectiveness_score: Mapped[float | None] = mapped_column(Numeric(4, 3))
    status: Mapped[str] = mapped_column(String, default="active", nullable=False)
    started_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
    ended_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
