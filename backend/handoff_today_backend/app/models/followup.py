from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from app.core.db import Base
from app.models.common import JsonType


class FollowupQuestion(Base):
    __tablename__ = "followup_questions"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    raw_memory_id: Mapped[str | None] = mapped_column(ForeignKey("raw_memories.id", ondelete="CASCADE"))
    related_pattern_id: Mapped[str | None] = mapped_column(String)
    related_friction_id: Mapped[str | None] = mapped_column(String)
    question_type: Mapped[str] = mapped_column(String)
    question_text: Mapped[str] = mapped_column(Text)
    options_json: Mapped[list] = mapped_column(JsonType, default=list, nullable=False)
    status: Mapped[str] = mapped_column(String, default="available", nullable=False)
    expires_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    answered_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())


class FollowupAnswer(Base):
    __tablename__ = "followup_answers"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    followup_question_id: Mapped[str] = mapped_column(ForeignKey("followup_questions.id", ondelete="CASCADE"))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    answer_value: Mapped[str] = mapped_column(String)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
