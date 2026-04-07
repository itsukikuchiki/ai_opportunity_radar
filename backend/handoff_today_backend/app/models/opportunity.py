from sqlalchemy import DateTime, ForeignKey, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from app.core.db import Base
from app.models.common import JsonType


class Opportunity(Base):
    __tablename__ = "opportunities"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String)
    description: Mapped[str | None] = mapped_column(Text)
    related_pattern_ids: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    related_friction_ids: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    related_desire_ids: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    opportunity_type: Mapped[str | None] = mapped_column(String)
    maturity: Mapped[str] = mapped_column(String, default="candidate", nullable=False)
    score_total: Mapped[float] = mapped_column(Numeric(4, 3), default=0, nullable=False)
    score_repeatability: Mapped[float] = mapped_column(Numeric(4, 3), default=0, nullable=False)
    score_pain: Mapped[float] = mapped_column(Numeric(4, 3), default=0, nullable=False)
    score_clarity: Mapped[float] = mapped_column(Numeric(4, 3), default=0, nullable=False)
    score_desire: Mapped[float] = mapped_column(Numeric(4, 3), default=0, nullable=False)
    score_ai_fit: Mapped[float] = mapped_column(Numeric(4, 3), default=0, nullable=False)
    expected_value: Mapped[str | None] = mapped_column(Text)
    recommendation: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String, default="open", nullable=False)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
