from __future__ import annotations

from app.schemas.capture_schema import (
    CaptureSubmitResponseSchema,
    RecentSignalSchema,
)
from app.services.classification_service import ClassificationService
from app.repositories.capture_repository import CaptureRepository


class CaptureService:
    def __init__(
        self,
        capture_repository: CaptureRepository,
        classification_service: ClassificationService,
    ):
        self.capture_repository = capture_repository
        self.classification_service = classification_service

    def submit_capture(
        self,
        user_id: str,
        content: str,
        input_mode: str = "quick_capture",
        tag_hint: str | None = None,
    ) -> CaptureSubmitResponseSchema:
        content = (content or "").strip()
        if not content:
            raise ValueError("content is required")

        previous_recent = self.capture_repository.list_recent_raw_memories(
            user_id=user_id,
            limit=10,
        )
        recent_assistant_texts = [
            item.get("acknowledgement")
            for item in previous_recent
            if item.get("acknowledgement")
        ]

        acknowledgement = self.classification_service.generate_acknowledgement(
            content,
            recent_assistant_texts=recent_assistant_texts,
        )

        created = self.capture_repository.create_capture(
            user_id=user_id,
            content=content,
            input_mode=input_mode,
            tag_hint=tag_hint,
            acknowledgement=acknowledgement,
        )

        recent = self.capture_repository.list_recent_raw_memories(
            user_id=user_id,
            limit=50,
        )

        created_id = created.get("id")
        created_exists = any(
            item.get("id") == created_id
            for item in recent
            if item.get("id") is not None
        )

        if not created_exists:
            recent = [
                {
                    "id": created.get("id"),
                    "content": created.get("content", content),
                    "created_at": created.get("created_at"),
                    "acknowledgement": created.get("acknowledgement", acknowledgement),
                },
                *recent,
            ]

        recent_schemas = [
            RecentSignalSchema(
                id=item.get("id"),
                content=item.get("content") or "",
                created_at=item.get("created_at"),
                acknowledgement=item.get("acknowledgement"),
            )
            for item in recent
        ]

        return CaptureSubmitResponseSchema(
            acknowledgement=acknowledgement,
            followup=None,
            recent_signals=recent_schemas,
        )
