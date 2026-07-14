from sqlalchemy import DateTime, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class ReflectionVersionRegistry(Base):
    __tablename__ = "reflection_version_registry"
    __table_args__ = (
        UniqueConstraint(
            "source_type",
            "reflection_type",
            "ai_level",
            name="uq_reflection_version_registry_key",
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    source_type: Mapped[str] = mapped_column(String, index=True)
    reflection_type: Mapped[str] = mapped_column(String, index=True)
    ai_level: Mapped[str] = mapped_column(String, index=True)
    prompt_version: Mapped[str] = mapped_column(String, nullable=False)
    model_version: Mapped[str] = mapped_column(String, nullable=False)
    pipeline_version: Mapped[str] = mapped_column(String, nullable=False)
    rollout_reason: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
