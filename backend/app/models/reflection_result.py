from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Text, desc, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class ReflectionResult(Base):
    __tablename__ = "reflection_results"
    __table_args__ = (
        Index(
            "idx_reflection_results_user_source",
            "user_id",
            "source_type",
            "source_id",
            "reflection_type",
            "status",
            desc("generated_at"),
        ),
        Index(
            "idx_reflection_results_cache_state",
            "source_type",
            "source_id",
            "dirty",
            "is_stale",
            "status",
        ),
        Index(
            "idx_reflection_results_user_source_state",
            "user_id",
            "source_type",
            "source_id",
            "dirty",
            "is_stale",
            desc("generated_at"),
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    source_type: Mapped[str] = mapped_column(String)
    source_id: Mapped[str] = mapped_column(String)
    reflection_type: Mapped[str] = mapped_column(String)
    ai_level: Mapped[str] = mapped_column(String)
    content_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    status: Mapped[str] = mapped_column(String, default="generated", nullable=False)
    schema_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    prompt_version: Mapped[str | None] = mapped_column(String)
    model_version: Mapped[str | None] = mapped_column(String)
    pipeline_version: Mapped[str] = mapped_column(
        String,
        default="v4_p0_05",
        nullable=False,
    )
    source_hash: Mapped[str | None] = mapped_column(Text)
    dirty: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_stale: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    stale_reason: Mapped[str | None] = mapped_column(Text)
    invalidated_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    generated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    confirmed_at: Mapped[object | None] = mapped_column(DateTime(timezone=True))
    superseded_by: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
