from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from sqlalchemy import select

from app.models import Capture, RawMemory
from app.repositories.core_repository import ensure_demo_user


class CaptureRepository:
    def __init__(self, db: Any):
        self.db = db

    def create_capture(
        self,
        user_id: str,
        content: str,
        input_mode: str = "quick_capture",
        tag_hint: str | None = None,
        acknowledgement: str | None = None,
    ) -> dict[str, Any]:
        ensure_demo_user(self.db, user_id)

        created_at = datetime.now(timezone.utc)
        capture_id = f"cap_{uuid4().hex[:12]}"
        raw_id = f"raw_{uuid4().hex[:12]}"

        capture = Capture(
            id=capture_id,
            user_id=user_id,
            content=content,
            input_mode=input_mode,
            tag_hint=tag_hint,
            created_at=created_at,
        )
        self.db.add(capture)

        metadata = {}
        if acknowledgement:
            metadata["acknowledgement"] = acknowledgement

        raw_memory = RawMemory(
            id=raw_id,
            user_id=user_id,
            capture_id=capture_id,
            source="capture",
            content=content,
            signal_type=None,
            scene_type=None,
            friction_type=None,
            emotion_strength=None,
            repetition_flag=False,
            desire_flag=False,
            related_pattern_id=None,
            related_friction_id=None,
            metadata_json=metadata,
            created_at=created_at,
        )
        self.db.add(raw_memory)
        self.db.commit()

        return {
            "id": raw_id,
            "content": content,
            "created_at": created_at,
            "acknowledgement": acknowledgement,
        }

    def list_recent_raw_memories(
        self,
        user_id: str,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        stmt = (
            select(RawMemory)
            .where(RawMemory.user_id == user_id)
            .order_by(RawMemory.created_at.desc())
            .limit(limit)
        )
        rows = list(self.db.scalars(stmt))

        def _ack(meta: Any) -> str | None:
            if not isinstance(meta, dict):
                return None
            return (
                meta.get("acknowledgement")
                or meta.get("ai_acknowledgement")
                or meta.get("response")
            )

        return [
            {
                "id": row.id,
                "content": row.content or "",
                "created_at": row.created_at,
                "acknowledgement": _ack(row.metadata_json),
            }
            for row in rows
        ]
