from datetime import datetime
from uuid import uuid4
from sqlalchemy.orm import Session
from app.models import Pattern, Friction, Desire, Opportunity
from app.repositories.memory_repository import MemoryRepository
from app.rules.scoring_rules import calculate_opportunity_score, map_maturity


PATTERN_NAMES = {
    'information_gathering': '重复资料整理',
    'writing': '重复写作准备',
    'decision_making': '反复比较再决定',
    'communication': '重复沟通对齐',
    'scheduling': '任务重新排程',
}
FRICTION_NAMES = {
    'information': '上下文分散导致启动困难',
    'time': '时间不足或频繁改期',
    'decision': '决策前反复比较',
    'execution': '执行启动困难',
    'coordination': '协作确认成本高',
    'emotional': '情绪消耗明显',
}
DESIRE_NAME = '希望省掉前置整理与重复准备'
OPPORTUNITY_NAME = '资料预整理 Copilot'


class MemoryService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = MemoryRepository(db)

    def update_from_classified_signal(self, user_id: str, raw_memory_id: str, classified_signal: dict, content: str) -> dict:
        now = datetime.utcnow()
        pattern = self._upsert_pattern(user_id, classified_signal, content, now)
        friction = self._upsert_friction(user_id, classified_signal, content, pattern.id if pattern else None, now)
        desire = self._upsert_desire(user_id, classified_signal, pattern.id if pattern else None, friction.id if friction else None, now)
        opportunity = self._upsert_opportunity(user_id, pattern, friction, desire, now)
        return {
            'pattern_id': pattern.id if pattern else None,
            'friction_id': friction.id if friction else None,
            'desire_id': desire.id if desire else None,
            'opportunity_id': opportunity.id if opportunity else None,
        }

    def _upsert_pattern(self, user_id: str, signal: dict, content: str, now: datetime):
        scene = signal.get('scene_type')
        if not scene or scene == 'other':
            return None
        row = self.repo.find_pattern(user_id, scene)
        if not row:
            row = self.repo.create_pattern(Pattern(
                id=f"pattern_{uuid4().hex[:8]}", user_id=user_id, name=PATTERN_NAMES.get(scene, '重复模式'),
                description=content, scene_type=scene, frequency_7d=1, frequency_30d=1,
                stability_score=0.3, confidence_score=0.4, first_seen_at=now, last_seen_at=now,
                status='observing', summary_json={'last_content': content}
            ))
        else:
            row.frequency_7d += 1
            row.frequency_30d += 1
            row.last_seen_at = now
            row.stability_score = min(float(row.stability_score) + 0.1, 1.0)
            row.confidence_score = min(float(row.confidence_score) + 0.1, 1.0)
            row.status = 'active' if row.frequency_7d >= 2 else row.status
            row.summary_json = {'last_content': content}
            self.db.flush()
        return row

    def _upsert_friction(self, user_id: str, signal: dict, content: str, pattern_id: str | None, now: datetime):
        friction_type = signal.get('friction_type')
        if not friction_type or friction_type == 'unknown':
            return None
        row = self.repo.find_friction(user_id, friction_type)
        if not row:
            row = self.repo.create_friction(Friction(
                id=f"friction_{uuid4().hex[:8]}", user_id=user_id, name=FRICTION_NAMES.get(friction_type, '主要摩擦'),
                friction_type=friction_type, description=content, severity_score=0.5,
                frequency_7d=1, frequency_30d=1, confidence_score=0.4,
                related_pattern_ids=[pattern_id] if pattern_id else [], representative_quotes=[content],
                first_seen_at=now, last_seen_at=now, status='observing'
            ))
        else:
            row.frequency_7d += 1
            row.frequency_30d += 1
            row.last_seen_at = now
            row.severity_score = min(float(row.severity_score) + 0.1, 1.0)
            row.confidence_score = min(float(row.confidence_score) + 0.1, 1.0)
            quotes = list(row.representative_quotes or [])
            if content not in quotes:
                quotes = ([content] + quotes)[:3]
            row.representative_quotes = quotes
            if pattern_id and pattern_id not in (row.related_pattern_ids or []):
                row.related_pattern_ids = list(row.related_pattern_ids or []) + [pattern_id]
            row.status = 'active' if row.frequency_7d >= 2 else row.status
            self.db.flush()
        return row

    def _upsert_desire(self, user_id: str, signal: dict, pattern_id: str | None, friction_id: str | None, now: datetime):
        if not signal.get('desire_flag'):
            return None
        row = self.repo.find_desire(user_id, DESIRE_NAME)
        if not row:
            row = self.repo.create_desire(Desire(
                id=f"desire_{uuid4().hex[:8]}", user_id=user_id, name=DESIRE_NAME, mention_count=1,
                priority_score=0.6, related_pattern_ids=[pattern_id] if pattern_id else [],
                related_friction_ids=[friction_id] if friction_id else [], first_seen_at=now, last_seen_at=now
            ))
        else:
            row.mention_count += 1
            row.priority_score = min(float(row.priority_score) + 0.1, 1.0)
            row.last_seen_at = now
            self.db.flush()
        return row

    def _upsert_opportunity(self, user_id: str, pattern, friction, desire, now: datetime):
        if not pattern or not friction:
            return None
        score = calculate_opportunity_score(
            {'frequency_7d': pattern.frequency_7d, 'frequency_30d': pattern.frequency_30d, 'stability_score': float(pattern.stability_score)},
            {'severity_score': float(friction.severity_score), 'frequency_7d': friction.frequency_7d},
            {'mention_count': desire.mention_count, 'priority_score': float(desire.priority_score)} if desire else None,
            clarity_score=4.0 if pattern.scene_type == 'information_gathering' else 3.0,
            ai_fit_score=4.0 if pattern.scene_type == 'information_gathering' else 3.0,
        )
        maturity = map_maturity(score)
        row = self.repo.find_opportunity(user_id, OPPORTUNITY_NAME)
        if not row:
            row = self.repo.create_opportunity(Opportunity(
                id=f"opp_{uuid4().hex[:8]}", user_id=user_id, name=OPPORTUNITY_NAME,
                description='在开始任务前，先帮助用户聚合上下文和资料。',
                related_pattern_ids=[pattern.id], related_friction_ids=[friction.id],
                related_desire_ids=[desire.id] if desire else [], opportunity_type='copilot', maturity=maturity,
                score_total=score['total'], score_repeatability=score['repeatability'], score_pain=score['pain'],
                score_clarity=score['clarity'], score_desire=score['desire'], score_ai_fit=score['ai_fit'],
                expected_value='减少启动前的资料整理时间', recommendation='先做一个预整理助手', status='open'
            ))
        else:
            row.related_pattern_ids = list({*(row.related_pattern_ids or []), pattern.id})
            row.related_friction_ids = list({*(row.related_friction_ids or []), friction.id})
            row.related_desire_ids = list({*(row.related_desire_ids or []), *( [desire.id] if desire else [])})
            row.maturity = maturity
            row.score_total = score['total']
            row.score_repeatability = score['repeatability']
            row.score_pain = score['pain']
            row.score_clarity = score['clarity']
            row.score_desire = score['desire']
            row.score_ai_fit = score['ai_fit']
            self.db.flush()
        return row

    def get_memory_summary(self, user_id: str) -> dict:
        patterns = self.repo.list_patterns(user_id, limit=10)
        frictions = self.repo.list_frictions(user_id, limit=10)
        desires = self.repo.list_desires(user_id, limit=10)
        return {
            'patterns': [{'id': p.id, 'name': p.name, 'status': p.status, 'summary': p.description or ''} for p in patterns],
            'frictions': [{'id': f.id, 'name': f.name, 'status': f.status, 'summary': f.description or ''} for f in frictions],
            'desires': [{'id': d.id, 'name': d.name, 'summary': d.description or d.name} for d in desires],
            'experiments': [],
        }
