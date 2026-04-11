from datetime import date, timedelta
from sqlalchemy.orm import Session
from app.repositories.core_repository import ensure_demo_user
from app.repositories.memory_repository import MemoryRepository
from app.repositories.weekly_repository import WeeklyRepository
from app.services.llm_service import LlmService


class WeeklyService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.memory_repo = MemoryRepository(db)
        self.weekly_repo = WeeklyRepository(db)
        self.llm = LlmService()

    def get_current_weekly(self, user_id: str) -> dict:
        ensure_demo_user(self.db, user_id)
        today = date.today()
        rolling_start = today - timedelta(days=6)
        user_created = self.memory_repo.get_user_created_date(user_id)
        if user_created:
            rolling_start = max(rolling_start, user_created + timedelta(days=1))

        existing = self.weekly_repo.find_by_user_and_week(user_id, rolling_start)
        if existing and existing.week_end == today:
            return {
                'week_start': existing.week_start.isoformat(),
                'week_end': existing.week_end.isoformat(),
                'status': existing.status,
                'key_insight': existing.key_insight,
                'patterns': existing.top_patterns_json,
                'frictions': existing.top_frictions_json,
                'best_action': existing.best_action,
                'opportunity_snapshot': existing.opportunity_snapshot_json,
                'feedback_submitted': existing.feedback_value is not None,
            }

        return self.generate_weekly(user_id, rolling_start, week_end=today)

    def get_weekly_by_start(self, user_id: str, week_start: date) -> dict:
        ensure_demo_user(self.db, user_id)
        existing = self.weekly_repo.find_by_user_and_week(user_id, week_start)
        if existing:
            return {
                'week_start': existing.week_start.isoformat(),
                'week_end': existing.week_end.isoformat(),
                'status': existing.status,
                'key_insight': existing.key_insight,
                'patterns': existing.top_patterns_json,
                'frictions': existing.top_frictions_json,
                'best_action': existing.best_action,
                'opportunity_snapshot': existing.opportunity_snapshot_json,
                'feedback_submitted': existing.feedback_value is not None,
            }
        return self.generate_weekly(user_id, week_start)

    def submit_feedback(self, user_id: str, week_start: date, feedback_value: str) -> dict:
        weekly = self.weekly_repo.submit_feedback(user_id, week_start, feedback_value)
        self.db.commit()
        if not weekly:
            raise ValueError('Weekly insight not found')
        return {'week_start': week_start.isoformat(), 'feedback_value': feedback_value, 'message': '周报反馈已记录。'}

    def generate_weekly(self, user_id: str, week_start: date, week_end: date | None = None) -> dict:
        week_end = week_end or (week_start + timedelta(days=6))
        summary = self.memory_repo.raw_summary(user_id, week_start, week_end)
        if summary['signal_count'] < 1:
            payload = {'week_start': week_start.isoformat(), 'week_end': week_end, 'status': 'insufficient_data'}
            row = self.weekly_repo.upsert(user_id, week_start, payload)
            self.db.commit()
            return {
                'week_start': week_start.isoformat(),
                'week_end': week_end.isoformat(),
                'status': 'insufficient_data',
                'message': '这一周的信号还不够多，我还不想太早下判断。',
            }
        patterns = self.memory_repo.list_patterns(user_id, limit=3)
        frictions = self.memory_repo.list_frictions(user_id, limit=2)
        opportunities = self.memory_repo.list_opportunities(user_id, maturity=None, status='open')[:1]
        generated = self.llm.generate_weekly({
            'user_profile': self.memory_repo.get_profile(user_id),
            'week_range': {'start': week_start.isoformat(), 'end': week_end.isoformat()},
            'raw_memory_summary': summary,
            'patterns': [{'id': p.id, 'name': p.name, 'description': p.description or ''} for p in patterns],
            'frictions': [{'id': f.id, 'name': f.name, 'description': f.description or ''} for f in frictions],
            'opportunities': [{'id': o.id, 'name': o.name, 'description': o.description or '', 'maturity': o.maturity} for o in opportunities],
            'recent_feedback': self.memory_repo.get_recent_feedback(user_id),
        })
        payload = {
            'week_start': week_start.isoformat(),
            'week_end': week_end,
            'status': 'available',
            'key_insight': generated['key_insight'],
            'patterns': generated['top_patterns'],
            'frictions': generated['top_frictions'],
            'best_action': generated['best_action'],
            'opportunity_snapshot': generated.get('opportunity_snapshot'),
        }
        self.weekly_repo.upsert(user_id, week_start, payload)
        self.db.commit()
        return {
            'week_start': week_start.isoformat(),
            'week_end': week_end.isoformat(),
            'status': 'available',
            'key_insight': generated['key_insight'],
            'patterns': generated['top_patterns'],
            'frictions': generated['top_frictions'],
            'best_action': generated['best_action'],
            'opportunity_snapshot': generated.get('opportunity_snapshot'),
            'feedback_submitted': False,
        }
