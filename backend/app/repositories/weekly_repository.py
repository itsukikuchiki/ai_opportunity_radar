from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import WeeklyInsight


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
        self.db.flush()
        return row

    def submit_feedback(self, user_id: str, week_start: date, feedback_value: str) -> WeeklyInsight | None:
        weekly = self.find_by_user_and_week(user_id, week_start)
        if weekly:
            weekly.feedback_value = feedback_value
            self.db.flush()
        return weekly
