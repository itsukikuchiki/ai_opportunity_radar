from datetime import datetime, timedelta, date
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from app.models import Pattern, Friction, Desire, Opportunity, RawMemory, UserProfile, WeeklyInsight


class MemoryRepository:
    def __init__(self, db: Session):
        self.db = db

    def find_pattern(self, user_id: str, scene_type: str | None) -> Pattern | None:
        if not scene_type or scene_type == 'other':
            return None
        stmt = select(Pattern).where(Pattern.user_id == user_id, Pattern.scene_type == scene_type).order_by(Pattern.updated_at.desc())
        return self.db.scalars(stmt).first()

    def create_pattern(self, pattern: Pattern) -> Pattern:
        self.db.add(pattern)
        self.db.flush()
        return pattern

    def find_friction(self, user_id: str, friction_type: str | None) -> Friction | None:
        if not friction_type or friction_type == 'unknown':
            return None
        stmt = select(Friction).where(Friction.user_id == user_id, Friction.friction_type == friction_type).order_by(Friction.updated_at.desc())
        return self.db.scalars(stmt).first()

    def create_friction(self, friction: Friction) -> Friction:
        self.db.add(friction)
        self.db.flush()
        return friction

    def find_desire(self, user_id: str, name: str) -> Desire | None:
        stmt = select(Desire).where(Desire.user_id == user_id, Desire.name == name)
        return self.db.scalars(stmt).first()

    def create_desire(self, desire: Desire) -> Desire:
        self.db.add(desire)
        self.db.flush()
        return desire

    def find_opportunity(self, user_id: str, name: str) -> Opportunity | None:
        stmt = select(Opportunity).where(Opportunity.user_id == user_id, Opportunity.name == name)
        return self.db.scalars(stmt).first()

    def create_opportunity(self, opportunity: Opportunity) -> Opportunity:
        self.db.add(opportunity)
        self.db.flush()
        return opportunity

    def list_patterns(self, user_id: str, limit: int = 20) -> list[Pattern]:
        stmt = select(Pattern).where(Pattern.user_id == user_id).order_by(Pattern.updated_at.desc()).limit(limit)
        return list(self.db.scalars(stmt))

    def list_frictions(self, user_id: str, limit: int = 20) -> list[Friction]:
        stmt = select(Friction).where(Friction.user_id == user_id).order_by(Friction.updated_at.desc()).limit(limit)
        return list(self.db.scalars(stmt))

    def list_desires(self, user_id: str, limit: int = 20) -> list[Desire]:
        stmt = select(Desire).where(Desire.user_id == user_id).order_by(Desire.updated_at.desc()).limit(limit)
        return list(self.db.scalars(stmt))

    def list_opportunities(self, user_id: str, status: str | None = None, maturity: str | None = None) -> list[Opportunity]:
        stmt = select(Opportunity).where(Opportunity.user_id == user_id)
        if status:
            stmt = stmt.where(Opportunity.status == status)
        if maturity:
            stmt = stmt.where(Opportunity.maturity == maturity)
        stmt = stmt.order_by(Opportunity.updated_at.desc())
        return list(self.db.scalars(stmt))

    def get_opportunity(self, user_id: str, opportunity_id: str) -> Opportunity | None:
        stmt = select(Opportunity).where(Opportunity.user_id == user_id, Opportunity.id == opportunity_id)
        return self.db.scalars(stmt).first()

    def get_profile(self, user_id: str) -> dict:
        profile = self.db.get(UserProfile, user_id)
        if not profile:
            return {}
        return {
            'selected_repeat_area': profile.selected_repeat_area,
            'selected_ai_help_type': profile.selected_ai_help_type,
            'selected_output_preference': profile.selected_output_preference,
        }

    def get_recent_feedback(self, user_id: str) -> dict:
        stmt = select(WeeklyInsight).where(WeeklyInsight.user_id == user_id).order_by(WeeklyInsight.week_start.desc()).limit(1)
        weekly = self.db.scalars(stmt).first()
        return {'weekly_feedback_last_week': weekly.feedback_value if weekly else None}

    def get_first_signal_date(self, user_id: str) -> date | None:
        stmt = select(func.min(RawMemory.created_at)).where(RawMemory.user_id == user_id)
        first_dt = self.db.execute(stmt).scalar_one_or_none()
        if first_dt is None:
            return None
        return first_dt.date()

    def raw_summary(self, user_id: str, week_start: date, week_end: date) -> dict:
        start_dt = datetime.combine(week_start, datetime.min.time())
        end_dt = datetime.combine(week_end + timedelta(days=1), datetime.min.time())
        stmt = select(RawMemory).where(RawMemory.user_id == user_id, RawMemory.created_at >= start_dt, RawMemory.created_at < end_dt)
        raws = list(self.db.scalars(stmt))
        scene_counts = {}
        friction_counts = {}
        for r in raws:
            if r.scene_type:
                scene_counts[r.scene_type] = scene_counts.get(r.scene_type, 0) + 1
            if r.friction_type:
                friction_counts[r.friction_type] = friction_counts.get(r.friction_type, 0) + 1
        return {
            'signal_count': len(raws),
            'top_scene_types': [k for k, _ in sorted(scene_counts.items(), key=lambda kv: kv[1], reverse=True)[:3]],
            'top_friction_types': [k for k, _ in sorted(friction_counts.items(), key=lambda kv: kv[1], reverse=True)[:3]],
        }
