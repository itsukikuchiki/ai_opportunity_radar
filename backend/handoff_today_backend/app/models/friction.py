from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from app.core.db import Base
from app.models.common import JsonType


class Friction(Base):
    __tablename__ = "frictions"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String)
    friction_type: Mapped[str] = mapped_column(String)
    description: Mapped[str | None] = mapped_column(Text)
    severity_score: Mapped[float] = mapped_column(Numeric(4, 3), default=0, nullable=False)
    frequency_7d: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    frequency_30d: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    confidence_score: Mapped[float] = mapped_column(Numeric(4, 3), default=0, nullable=False)
    related_pattern_ids: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    representative_quotes: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    first_seen_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    last_seen_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(String, default="candidate", nullable=False)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
