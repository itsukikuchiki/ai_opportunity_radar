from datetime import datetime, timedelta, date
from uuid import uuid4

from sqlalchemy.orm import Session
from sqlalchemy import select, func

from app.models import (
    Pattern,
    Friction,
    Desire,
    Opportunity,
    RawMemory,
    UserProfile,
    WeeklyInsight,
    Capture,
)


class MemoryRepository:
    def __init__(self, db: Session):
        self.db = db

    def find_pattern(self, user_id: str, scene_type: str | None) -> Pattern | None:
        if not scene_type or scene_type == 'other':
            return None
        stmt = select(Pattern).where(
            Pattern.user_id == user_id,
            Pattern.scene_type == scene_type,
        ).order_by(Pattern.updated_at.desc())
        return self.db.scalars(stmt).first()

    def create_pattern(self, pattern: Pattern) -> Pattern:
        self.db.add(pattern)
        self.db.flush()
        return pattern

    def find_friction(self, user_id: str, friction_type: str | None) -> Friction | None:
        if not friction_type or friction_type == 'unknown':
            return None
        stmt = select(Friction).where(
            Friction.user_id == user_id,
            Friction.friction_type == friction_type,
        ).order_by(Friction.updated_at.desc())
        return self.db.scalars(stmt).first()

    def create_friction(self, friction: Friction) -> Friction:
        self.db.add(friction)
        self.db.flush()
        return friction

    def find_desire(self, user_id: str, name: str) -> Desire | None:
        stmt = select(Desire).where(
            Desire.user_id == user_id,
            Desire.name == name,
        )
        return self.db.scalars(stmt).first()

    def create_desire(self, desire: Desire) -> Desire:
        self.db.add(desire)
        self.db.flush()
        return desire

    def find_opportunity(self, user_id: str, name: str) -> Opportunity | None:
        stmt = select(Opportunity).where(
            Opportunity.user_id == user_id,
            Opportunity.name == name,
        )
        return self.db.scalars(stmt).first()

    def create_opportunity(self, opportunity: Opportunity) -> Opportunity:
        self.db.add(opportunity)
        self.db.flush()
        return opportunity

    def list_patterns(self, user_id: str, limit: int = 20) -> list[Pattern]:
        self._backfill_missing_raw_memories(user_id)
        stmt = select(Pattern).where(
            Pattern.user_id == user_id,
        ).order_by(Pattern.updated_at.desc()).limit(limit)
        return list(self.db.scalars(stmt))

    def list_frictions(self, user_id: str, limit: int = 20) -> list[Friction]:
        self._backfill_missing_raw_memories(user_id)
        stmt = select(Friction).where(
            Friction.user_id == user_id,
        ).order_by(Friction.updated_at.desc()).limit(limit)
        return list(self.db.scalars(stmt))

    def list_desires(self, user_id: str, limit: int = 20) -> list[Desire]:
        self._backfill_missing_raw_memories(user_id)
        stmt = select(Desire).where(
            Desire.user_id == user_id,
        ).order_by(Desire.updated_at.desc()).limit(limit)
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
        stmt = select(Opportunity).where(
            Opportunity.user_id == user_id,
            Opportunity.id == opportunity_id,
        )
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
        stmt = select(WeeklyInsight).where(
            WeeklyInsight.user_id == user_id,
        ).order_by(WeeklyInsight.week_start.desc()).limit(1)
        weekly = self.db.scalars(stmt).first()
        return {'weekly_feedback_last_week': weekly.feedback_value if weekly else None}

    def get_first_signal_date(self, user_id: str) -> date | None:
        """
        先回填旧 Capture -> RawMemory，再从 RawMemory 取首条时间。
        这样升级前数据也会计入 Weekly / Journey 的起始日。
        """
        self._backfill_missing_raw_memories(user_id)

        stmt = select(func.min(RawMemory.created_at)).where(
            RawMemory.user_id == user_id,
        )
        first_dt = self.db.execute(stmt).scalar_one_or_none()
        if first_dt is None:
            return None
        return first_dt.date()

    def raw_summary(self, user_id: str, week_start: date, week_end: date) -> dict:
        """
        周统计前先做回填，确保旧 Capture 数据能被纳入 signal_count。
        旧数据即便还没有 scene/friction 分类，也至少应计入 signal_count。
        """
        self._backfill_missing_raw_memories(user_id)

        start_dt = datetime.combine(week_start, datetime.min.time())
        end_dt = datetime.combine(week_end + timedelta(days=1), datetime.min.time())

        stmt = select(RawMemory).where(
            RawMemory.user_id == user_id,
            RawMemory.created_at >= start_dt,
            RawMemory.created_at < end_dt,
        )
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
            'top_scene_types': [
                k for k, _ in sorted(
                    scene_counts.items(),
                    key=lambda kv: kv[1],
                    reverse=True,
                )[:3]
            ],
            'top_friction_types': [
                k for k, _ in sorted(
                    friction_counts.items(),
                    key=lambda kv: kv[1],
                    reverse=True,
                )[:3]
            ],
        }

    def _backfill_missing_raw_memories(self, user_id: str) -> int:
        """
        懒回填：
        如果用户旧版本只有 Capture，没有 RawMemory，
        则在读取 Weekly / Journey 前自动补齐。
        """
        capture_stmt = (
            select(Capture)
            .where(Capture.user_id == user_id)
            .order_by(Capture.created_at.asc())
        )
        captures = list(self.db.scalars(capture_stmt))

        if not captures:
            return 0

        raw_capture_ids_stmt = select(RawMemory.capture_id).where(
            RawMemory.user_id == user_id,
            RawMemory.capture_id.is_not(None),
        )
        existing_capture_ids = {
            capture_id
            for capture_id in self.db.scalars(raw_capture_ids_stmt)
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
            self.db.commit()

        return created_count
