from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Capture, RawMemory


class CaptureRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_capture(
        self,
        user_id: str,
        content: str,
        input_mode: str = "quick_capture",
        tag_hint: str | None = None,
        acknowledgement: str | None = None,
    ) -> dict:
        now = datetime.now(timezone.utc)
        capture_id = f"cap_{uuid4().hex[:12]}"
        raw_id = f"raw_{uuid4().hex[:12]}"

        capture = Capture(
            id=capture_id,
            user_id=user_id,
            content=content,
            input_mode=input_mode,
            tag_hint=tag_hint,
            created_at=now,
        )
        self.db.add(capture)

        raw = RawMemory(
            id=raw_id,
            user_id=user_id,
            capture_id=capture_id,
            source=input_mode or "quick_capture",
            content=content,
            metadata_json={"acknowledgement": acknowledgement} if acknowledgement else {},
            created_at=now,
        )
        self.db.add(raw)
        self.db.flush()

        return {
            "id": raw.id,
            "content": raw.content,
            "created_at": raw.created_at,
            "acknowledgement": acknowledgement,
        }

    def list_recent_raw_memories(
        self,
        user_id: str,
        limit: int = 50,
    ) -> list[dict]:
        stmt = (
            select(RawMemory)
            .where(RawMemory.user_id == user_id)
            .order_by(RawMemory.created_at.desc())
            .limit(limit)
        )
        rows = list(self.db.scalars(stmt))

        return [
            {
                "id": row.id,
                "content": row.content or "",
                "created_at": row.created_at,
                "acknowledgement": (row.metadata_json or {}).get("acknowledgement"),
            }
            for row in rows
        ]
