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

    def backfill_missing_raw_memories(
        self,
        user_id: str,
        commit: bool = True,
    ) -> int:
        """
        将旧版本只存在于 Capture、但还没有对应 RawMemory 的数据补齐。
        """
        ensure_demo_user(self.db, user_id)

        capture_stmt = (
            select(Capture)
            .where(Capture.user_id == user_id)
            .order_by(Capture.created_at.asc())
        )
        captures = list(self.db.scalars(capture_stmt))

        raw_stmt = select(RawMemory.capture_id).where(
            RawMemory.user_id == user_id,
            RawMemory.capture_id.is_not(None),
        )
        existing_capture_ids = {
            capture_id
            for capture_id in self.db.scalars(raw_stmt)
            if capture_id
        }

        created_count = 0

        for capture in captures:
            if capture.id in existing_capture_ids:
                continue

            raw_memory = RawMemory(
                id=f"raw_{uuid4().hex[:12]}",
                user_id=user_id,
                capture_id=capture.id,
                source="capture",
                content=capture.content or "",
                signal_type=None,
                scene_type=None,
                friction_type=None,
                emotion_strength=None,
                repetition_flag=False,
                desire_flag=False,
                related_pattern_id=None,
                related_friction_id=None,
                metadata_json={},
                created_at=capture.created_at,
            )
            self.db.add(raw_memory)
            created_count += 1

        if created_count > 0:
            self.db.flush()
            if commit:
                self.db.commit()
        elif commit:
            # 保持调用方逻辑简单
            self.db.rollback()

        return created_count

    def list_recent_raw_memories(
        self,
        user_id: str,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        """
        读取 recent signals 前，先把旧 Capture 回填到 RawMemory，
        这样旧版本数据也能被 Today 正常读到。
        """
        self.backfill_missing_raw_memories(user_id=user_id, commit=True)

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
