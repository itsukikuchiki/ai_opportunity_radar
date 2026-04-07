from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


_CAPTURE_STORE: list[dict[str, Any]] = []


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
        item = {
            "id": f"cap_{len(_CAPTURE_STORE) + 1}",
            "user_id": user_id,
            "content": content,
            "input_mode": input_mode,
            "tag_hint": tag_hint,
            "acknowledgement": acknowledgement,
            "created_at": datetime.now(timezone.utc),
        }
        _CAPTURE_STORE.append(item)
        return item

    def list_recent_raw_memories(
        self,
        user_id: str,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        rows = [
            row for row in _CAPTURE_STORE
            if row.get("user_id") == user_id
        ]
        rows.sort(
            key=lambda x: x.get("created_at") or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
        rows = rows[:limit]

        return [
            {
                "id": row.get("id"),
                "content": row.get("content") or "",
                "created_at": row.get("created_at"),
                "acknowledgement": row.get("acknowledgement"),
            }
            for row in rows
        ]
