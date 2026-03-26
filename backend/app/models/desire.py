from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from app.core.db import Base
from app.models.common import JsonType


class Desire(Base):
    __tablename__ = "desires"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String)
    description: Mapped[str | None] = mapped_column(Text)
    mention_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    priority_score: Mapped[float] = mapped_column(Numeric(4, 3), default=0, nullable=False)
    related_pattern_ids: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    related_friction_ids: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    first_seen_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    last_seen_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
