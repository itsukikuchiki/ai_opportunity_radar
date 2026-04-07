from sqlalchemy.orm import Session
from sqlalchemy import select
from app.models import Capture, RawMemory, FollowupQuestion


class CaptureRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_capture(self, capture: Capture) -> Capture:
        self.db.add(capture)
        self.db.flush()
        return capture

    def create_raw_memory(self, raw: RawMemory) -> RawMemory:
        self.db.add(raw)
        self.db.flush()
        return raw

    def list_recent_raw_memories(self, user_id: str, limit: int = 3) -> list[RawMemory]:
        stmt = select(RawMemory).where(RawMemory.user_id == user_id).order_by(RawMemory.created_at.desc()).limit(limit)
        return list(self.db.scalars(stmt))

    def create_followup(self, followup: FollowupQuestion) -> FollowupQuestion:
        self.db.add(followup)
        self.db.flush()
        return followup
