from uuid import uuid4
from sqlalchemy.orm import Session
from app.models import Capture, RawMemory
from app.repositories.capture_repository import CaptureRepository
from app.repositories.core_repository import ensure_demo_user
from app.services.classification_service import ClassificationService
from app.services.memory_service import MemoryService
from app.services.followup_service import FollowupService


class CaptureService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repo = CaptureRepository(db)
        self.classifier = ClassificationService()
        self.memory = MemoryService(db)
        self.followups = FollowupService(db)

    def submit_capture(self, user_id: str, content: str, input_mode: str, tag_hint: str | None = None) -> dict:
        ensure_demo_user(self.db, user_id)
        capture = Capture(
            id=f"cap_{uuid4().hex[:8]}",
            user_id=user_id,
            content=content,
            input_mode=input_mode,
            tag_hint=tag_hint,
        )
        self.repo.create_capture(capture)
        classified = self.classifier.classify_capture(content, tag_hint)
        raw = RawMemory(
            id=f"raw_{uuid4().hex[:8]}",
            user_id=user_id,
            capture_id=capture.id,
            source=input_mode,
            content=content,
            signal_type=classified['signal_type'],
            scene_type=classified['scene_type'],
            friction_type=classified['friction_type'],
            emotion_strength=classified['emotion_strength'],
            repetition_flag=classified['repetition_flag'],
            desire_flag=classified['desire_flag'],
            metadata_json={'tag_hint': tag_hint},
        )
        self.repo.create_raw_memory(raw)
        memory_result = self.memory.update_from_classified_signal(user_id, raw.id, classified, content)
        raw.related_pattern_id = memory_result.get('pattern_id')
        raw.related_friction_id = memory_result.get('friction_id')
        followup = self.followups.maybe_generate_followup(
            user_id=user_id,
            raw_memory_id=raw.id,
            classified_signal=classified,
            related_pattern_id=memory_result.get('pattern_id'),
            related_friction_id=memory_result.get('friction_id'),
        )
        recent = self.repo.list_recent_raw_memories(user_id)
        self.db.commit()
        return {
            'capture_id': capture.id,
            'acknowledgement': self.classifier.generate_acknowledgement(content, classified),
            'classified_signal': classified,
            'followup': followup,
            'recent_signals': [{'content': r.content} for r in recent],
        }
