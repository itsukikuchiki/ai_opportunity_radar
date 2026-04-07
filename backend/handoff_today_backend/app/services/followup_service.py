from datetime import datetime, timedelta
from uuid import uuid4
from sqlalchemy.orm import Session
from app.models import FollowupQuestion, FollowupAnswer
from app.services.llm_service import LlmService


class FollowupService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.llm = LlmService()

    def maybe_generate_followup(self, user_id: str, raw_memory_id: str, classified_signal: dict, related_pattern_id: str | None = None, related_friction_id: str | None = None) -> dict | None:
        if classified_signal.get('scene_type') == 'information_gathering' or classified_signal.get('friction_type') == 'information':
            q = self.llm.generate_followup_question({})
            row = FollowupQuestion(
                id=f"fu_{uuid4().hex[:8]}",
                user_id=user_id,
                raw_memory_id=raw_memory_id,
                related_pattern_id=related_pattern_id,
                related_friction_id=related_friction_id,
                question_type=q['question_type'],
                question_text=q['question_text'],
                options_json=q['options'],
                expires_at=datetime.utcnow() + timedelta(days=7),
            )
            self.db.add(row)
            self.db.flush()
            return {'id': row.id, 'question': row.question_text, 'options': row.options_json}
        return None

    def submit_answer(self, user_id: str, followup_id: str, answer_value: str) -> dict:
        question = self.db.get(FollowupQuestion, followup_id)
        if not question:
            raise ValueError('Follow-up not found')
        self.db.add(FollowupAnswer(id=f"fa_{uuid4().hex[:8]}", followup_question_id=followup_id, user_id=user_id, answer_value=answer_value))
        question.status = 'skipped' if answer_value == 'skip' else 'answered'
        question.answered_at = datetime.utcnow()
        self.db.flush()
        return {
            'followup_id': followup_id,
            'status': question.status,
            'message': '好，我会把这类问题更多理解成“找资料”带来的启动摩擦。' if answer_value != 'skip' else '好，我先不追问这个。',
        }
