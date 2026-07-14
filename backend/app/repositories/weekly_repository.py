from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import WeeklyInsight
from app.repositories.pipeline_run_repository import PipelineRunRepository
from app.repositories.reflection_result_repository import ReflectionResultRepository


class WeeklyRepository:
    def __init__(self, db: Session):
        self.db = db

    def find_by_user_and_week(self, user_id: str, week_start: date) -> WeeklyInsight | None:
        stmt = select(WeeklyInsight).where(
            WeeklyInsight.user_id == user_id,
            WeeklyInsight.week_start == week_start,
        )
        return self.db.scalars(stmt).first()

    def upsert(self, user_id: str, week_start: date, payload: dict) -> WeeklyInsight:
        existing = self.find_by_user_and_week(user_id, week_start)

        if existing:
            existing.week_end = payload["week_end"]
            existing.status = payload["status"]
            existing.key_insight = payload.get("key_insight")
            existing.top_patterns_json = payload.get("patterns", [])
            existing.top_frictions_json = payload.get("frictions", [])
            existing.best_action = payload.get("best_action")
            existing.opportunity_snapshot_json = payload.get("opportunity_snapshot")
            existing.chart_data_json = payload.get("chart_data", [])
            self._record_pipeline_run(user_id, week_start, payload)
            self._save_reflection_result(user_id, week_start, payload)
            self.db.flush()
            return existing

        row = WeeklyInsight(
            id=f"weekly_{user_id}_{week_start.isoformat()}",
            user_id=user_id,
            week_start=week_start,
            week_end=payload["week_end"],
            status=payload["status"],
            key_insight=payload.get("key_insight"),
            top_patterns_json=payload.get("patterns", []),
            top_frictions_json=payload.get("frictions", []),
            best_action=payload.get("best_action"),
            opportunity_snapshot_json=payload.get("opportunity_snapshot"),
            chart_data_json=payload.get("chart_data", []),
        )
        self.db.add(row)
        self._record_pipeline_run(user_id, week_start, payload)
        self._save_reflection_result(user_id, week_start, payload)
        self.db.flush()
        return row

    def submit_feedback(self, user_id: str, week_start: date, feedback_value: str) -> WeeklyInsight | None:
        weekly = self.find_by_user_and_week(user_id, week_start)
        if weekly:
            weekly.feedback_value = feedback_value
            self.db.flush()
        return weekly

    def _save_reflection_result(
        self,
        user_id: str,
        week_start: date,
        payload: dict,
    ) -> None:
        ReflectionResultRepository(self.db).save_current(
            user_id=user_id,
            source_type="weekly_snapshot",
            source_id=week_start.isoformat(),
            reflection_type="reflect",
            ai_level="L3",
            content={
                "key_insight": payload.get("key_insight"),
                "patterns": payload.get("patterns", []),
                "frictions": payload.get("frictions", []),
                "best_action": payload.get("best_action"),
                "opportunity_snapshot": payload.get("opportunity_snapshot"),
            },
            source_hash=payload.get("source_hash"),
        )

    def _record_pipeline_run(
        self,
        user_id: str,
        week_start: date,
        payload: dict,
    ) -> None:
        PipelineRunRepository(self.db).record_completed(
            user_id=user_id,
            pipeline_type="weekly_aggregation",
            source_type="weekly_snapshot",
            source_id=week_start.isoformat(),
            input_hash=payload.get("source_hash"),
            output_hash=payload.get("source_hash"),
        )
