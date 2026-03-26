from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from app.core.db import Base
from app.models.common import JsonType


class RawMemory(Base):
    __tablename__ = "raw_memories"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    capture_id: Mapped[str | None] = mapped_column(ForeignKey("captures.id", ondelete="SET NULL"))
    source: Mapped[str] = mapped_column(String)
    content: Mapped[str] = mapped_column(Text)
    signal_type: Mapped[str | None] = mapped_column(String)
    scene_type: Mapped[str | None] = mapped_column(String)
    friction_type: Mapped[str | None] = mapped_column(String)
    emotion_strength: Mapped[str | None] = mapped_column(String)
    repetition_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    desire_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    related_pattern_id: Mapped[str | None] = mapped_column(String)
    related_friction_id: Mapped[str | None] = mapped_column(String)
    metadata_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
