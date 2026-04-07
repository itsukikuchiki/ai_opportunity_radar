from uuid import uuid4
from sqlalchemy.orm import Session
from app.models import Experiment
from app.repositories.memory_repository import MemoryRepository
from app.services.llm_service import LlmService


class OpportunityService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repo = MemoryRepository(db)
        self.llm = LlmService()

    def list_opportunities(self, user_id: str, status: str | None = None, maturity: str | None = None) -> list[dict]:
        items = self.repo.list_opportunities(user_id, status=status, maturity=maturity)
        return [
            {
                'id': o.id,
                'name': o.name,
                'maturity': o.maturity,
                'opportunity_type': o.opportunity_type,
                'score_total': float(o.score_total),
                'summary': o.description or '',
            }
            for o in items
        ]

    def get_opportunity_detail(self, user_id: str, opportunity_id: str) -> dict:
        o = self.repo.get_opportunity(user_id, opportunity_id)
        if not o:
            raise ValueError('Opportunity not found')
        generated = self.llm.generate_opportunity_explanation({})
        return {
            'id': o.id,
            'name': o.name,
            'description': o.description,
            'maturity': o.maturity,
            'opportunity_type': o.opportunity_type,
            'score': {
                'repeatability': float(o.score_repeatability),
                'pain': float(o.score_pain),
                'clarity': float(o.score_clarity),
                'desire': float(o.score_desire),
                'ai_fit': float(o.score_ai_fit),
                'total': float(o.score_total),
            },
            **generated,
        }

    def submit_feedback(self, user_id: str, opportunity_id: str, feedback_value: str) -> dict:
        o = self.repo.get_opportunity(user_id, opportunity_id)
        if not o:
            raise ValueError('Opportunity not found')
        status = o.status
        if feedback_value == 'want_to_try':
            status = 'testing'
            self.db.add(Experiment(id=f"exp_{uuid4().hex[:8]}", user_id=user_id, opportunity_id=o.id, name=f"试点：{o.name}", hypothesis='验证此机会是否值得进一步建设'))
        elif feedback_value == 'not_this':
            status = 'rejected'
        elif feedback_value == 'too_early':
            o.maturity = 'observing'
        o.status = status
        self.db.commit()
        return {'opportunity_id': opportunity_id, 'status': status, 'message': '反馈已记录。'}
