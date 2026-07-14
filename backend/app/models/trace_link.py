from sqlalchemy import DateTime, Float, ForeignKey, Index, String, UniqueConstraint, desc, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models.common import JsonType


class TraceLink(Base):
    __tablename__ = "trace_links"
    __table_args__ = (
        UniqueConstraint(
            "source_type",
            "source_id",
            "target_type",
            "target_id",
            "relation_type",
            name="uq_trace_links_source_target_relation",
        ),
        Index(
            "idx_trace_links_source",
            "source_type",
            "source_id",
            "relation_type",
            "status",
        ),
        Index(
            "idx_trace_links_target",
            "target_type",
            "target_id",
            "relation_type",
            "status",
        ),
        Index(
            "idx_trace_links_user_status",
            "user_id",
            "status",
            desc("updated_at"),
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
    )
    source_type: Mapped[str] = mapped_column(String)
    source_id: Mapped[str] = mapped_column(String)
    target_type: Mapped[str] = mapped_column(String)
    target_id: Mapped[str] = mapped_column(String)
    relation_type: Mapped[str] = mapped_column(String)
    weight: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    status: Mapped[str] = mapped_column(String, default="active")
    metadata_json: Mapped[dict] = mapped_column(JsonType, default=dict, nullable=False)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
