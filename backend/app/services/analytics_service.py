from __future__ import annotations

import json
from collections import defaultdict
from datetime import date, datetime, timedelta
from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.analytics import AiUsage, AnalyticsEvent, UserSubscription
from app.models.user import User
from app.models.weekly_insight import WeeklyInsight


class AnalyticsService:
    monthly_product_id = "jp.sunrise.signalpath.pro.monthly"
    yearly_product_id = "jp.sunrise.signalpath.pro.yearly"
    monthly_price_usd = 0.99
    yearly_price_usd = 9.99

    def __init__(self, db: Session):
        self.db = db

    def ensure_user(self, user_id: str) -> None:
        if self.db.get(User, user_id) is None:
            self.db.add(User(id=user_id))
            self.db.flush()

    def track_event(
        self,
        *,
        user_id: str,
        event_name: str,
        properties: dict | None = None,
        numeric_value: float | None = None,
        commit: bool = True,
    ) -> AnalyticsEvent:
        self.ensure_user(user_id)
        now = datetime.utcnow()
        event = AnalyticsEvent(
            id=str(uuid4()),
            user_id=user_id,
            event_name=event_name.strip(),
            event_date=now.date(),
            properties_json=properties or {},
            numeric_value=numeric_value,
        )
        self.db.add(event)
        if commit:
            self.db.commit()
        return event

    def record_ai_usage(
        self,
        *,
        user_id: str,
        endpoint: str,
        request_payload: object,
        response_payload: object,
        commit: bool = True,
    ) -> AiUsage:
        self.ensure_user(user_id)
        input_tokens = self._estimate_tokens(request_payload)
        output_tokens = self._estimate_tokens(response_payload)
        usage = AiUsage(
            id=str(uuid4()),
            user_id=user_id,
            endpoint=endpoint,
            estimated_input_tokens=input_tokens,
            estimated_output_tokens=output_tokens,
            estimated_cost_usd=0.0,
        )
        self.db.add(usage)
        self.track_event(
            user_id=user_id,
            event_name="ai_request",
            properties={
                "endpoint": endpoint,
                "estimated_input_tokens": input_tokens,
                "estimated_output_tokens": output_tokens,
                "estimated_cost_usd": 0.0,
            },
            commit=False,
        )
        if commit:
            self.db.commit()
        return usage

    def upsert_subscription(
        self,
        *,
        user_id: str,
        product_id: str,
        verified: bool,
        environment: str | None,
        reason: str | None,
        transaction_date: str | None,
        commit: bool = True,
    ) -> UserSubscription:
        self.ensure_user(user_id)
        subscription = self.db.get(UserSubscription, user_id)
        if subscription is None:
            subscription = UserSubscription(user_id=user_id)
            self.db.add(subscription)

        subscription.product_id = product_id
        subscription.status = "active" if verified else "inactive"
        subscription.environment = environment
        subscription.reason = reason
        subscription.transaction_date = transaction_date
        subscription.latest_verified_at = datetime.utcnow()

        self.track_event(
            user_id=user_id,
            event_name="purchase_success" if verified else "purchase_verify_failed",
            properties={
                "product_id": product_id,
                "environment": environment,
                "reason": reason,
            },
            commit=False,
        )
        if commit:
            self.db.commit()
        return subscription

    def metrics_summary(self, *, days: int = 30) -> dict:
        now = datetime.utcnow()
        today = now.date()
        last_1d = now - timedelta(days=1)
        last_7d = now - timedelta(days=7)
        last_30d = now - timedelta(days=days)

        registered_users = self._scalar_count(select(func.count(User.id)))
        dau_users = self._distinct_event_users("app_open", last_1d)
        wau_users = self._distinct_event_users("app_open", last_7d)
        active_7d_users = self._active_users(last_7d)
        active_30d_users = self._active_users(last_30d)

        entry_count_7d = self._event_count("entry_created", last_7d)
        weekly_open_users = self._distinct_event_users("weekly_open", last_7d)
        journey_open_users = self._distinct_event_users("journey_open", last_7d)

        paid_users = self._scalar_count(
            select(func.count(UserSubscription.user_id)).where(
                UserSubscription.status == "active"
            )
        )
        free_users = max(registered_users - paid_users, 0)

        ai_cost_30d = float(
            self.db.scalar(
                select(func.coalesce(func.sum(AiUsage.estimated_cost_usd), 0.0)).where(
                    AiUsage.created_at >= last_30d
                )
            )
            or 0.0
        )

        return {
            "generated_at": now.isoformat() + "Z",
            "window_days": days,
            "downloads": self._unavailable(
                "app_store_connect",
                "App Store Connect Analytics/Sales Reports need a valid analytics API role or vendor number.",
            ),
            "registered_users": registered_users,
            "dau": len(dau_users),
            "wau": len(wau_users),
            "retention": {
                "d1": self._retention(days_after_signup=1, today=today),
                "d7": self._retention(days_after_signup=7, today=today),
                "d30": self._retention(days_after_signup=30, today=today),
            },
            "avg_records_per_user_per_week": self._safe_rate(
                entry_count_7d,
                len(active_7d_users),
            ),
            "weekly_report_open_rate": self._safe_rate(
                len(weekly_open_users),
                len(active_7d_users),
            ),
            "journey_open_rate": self._safe_rate(
                len(journey_open_users),
                len(active_7d_users),
            ),
            "free_users": free_users,
            "paid_users": paid_users,
            "paid_conversion_rate": self._safe_rate(paid_users, registered_users),
            "mrr": self._mrr_summary(),
            "ai_avg_cost_per_user": {
                "value": self._safe_rate(ai_cost_30d, len(active_30d_users)),
                "currency": "USD",
                "note": "Current AI generation is rule-based/local, so estimated external model cost is 0 until a paid LLM provider is connected.",
            },
            "representative_feedback": self._representative_feedback(),
        }

    def _estimate_tokens(self, payload: object) -> int:
        text = json.dumps(payload, ensure_ascii=False, default=str)
        return max(1, len(text) // 4)

    def _scalar_count(self, stmt) -> int:
        return int(self.db.scalar(stmt) or 0)

    def _event_count(self, event_name: str, since: datetime) -> int:
        return self._scalar_count(
            select(func.count(AnalyticsEvent.id)).where(
                AnalyticsEvent.event_name == event_name,
                AnalyticsEvent.created_at >= since,
            )
        )

    def _distinct_event_users(self, event_name: str, since: datetime) -> set[str]:
        rows = self.db.scalars(
            select(AnalyticsEvent.user_id).where(
                AnalyticsEvent.event_name == event_name,
                AnalyticsEvent.created_at >= since,
            )
        )
        return set(rows.all())

    def _active_users(self, since: datetime) -> set[str]:
        rows = self.db.scalars(
            select(AnalyticsEvent.user_id).where(AnalyticsEvent.created_at >= since)
        )
        return set(rows.all())

    def _safe_rate(self, numerator: float, denominator: float) -> float | None:
        if denominator <= 0:
            return None
        return round(float(numerator) / float(denominator), 4)

    def _retention(self, *, days_after_signup: int, today: date) -> dict:
        cohort_date = today - timedelta(days=days_after_signup)
        users = self.db.scalars(select(User)).all()
        cohort = [
            user.id
            for user in users
            if self._to_date(user.created_at) == cohort_date
        ]
        if not cohort:
            return {
                "value": None,
                "cohort_date": cohort_date.isoformat(),
                "cohort_size": 0,
                "reason": "not_enough_cohort",
            }

        events = self.db.scalars(
            select(AnalyticsEvent).where(
                AnalyticsEvent.event_name == "app_open",
                AnalyticsEvent.user_id.in_(cohort),
            )
        ).all()
        dates_by_user: dict[str, set[date]] = defaultdict(set)
        for event in events:
            dates_by_user[event.user_id].add(event.event_date)

        retained_date = cohort_date + timedelta(days=days_after_signup)
        retained = sum(
            1
            for user_id in cohort
            if retained_date in dates_by_user[user_id]
        )
        return {
            "value": self._safe_rate(retained, len(cohort)),
            "cohort_date": cohort_date.isoformat(),
            "cohort_size": len(cohort),
            "retained_users": retained,
        }

    def _to_date(self, value: object) -> date | None:
        if isinstance(value, datetime):
            return value.date()
        if isinstance(value, date):
            return value
        return None

    def _mrr_summary(self) -> dict:
        subscriptions = self.db.scalars(
            select(UserSubscription).where(UserSubscription.status == "active")
        ).all()
        total = 0.0
        for subscription in subscriptions:
            if subscription.product_id == self.monthly_product_id:
                total += self.monthly_price_usd
            elif subscription.product_id == self.yearly_product_id:
                total += self.yearly_price_usd / 12

        return {
            "value": round(total, 2),
            "currency": "USD_estimate",
            "source": "active_subscription_product_ids",
            "note": "Uses configured product prices until App Store Sales Reports are connected.",
        }

    def _representative_feedback(self) -> list[dict]:
        event_rows = self.db.scalars(
            select(AnalyticsEvent)
            .where(AnalyticsEvent.event_name == "weekly_feedback")
            .order_by(AnalyticsEvent.created_at.desc())
            .limit(10)
        ).all()
        feedback = [
            {
                "source": "weekly_feedback_event",
                "user_id": row.user_id,
                "week_start": (row.properties_json or {}).get("week_start"),
                "feedback_value": (row.properties_json or {}).get("feedback_value"),
            }
            for row in event_rows
        ]

        if feedback:
            return feedback

        weekly_rows = self.db.execute(
            select(
                WeeklyInsight.user_id,
                WeeklyInsight.week_start,
                WeeklyInsight.feedback_value,
            )
            .where(WeeklyInsight.feedback_value.is_not(None))
            .order_by(WeeklyInsight.updated_at.desc())
            .limit(10)
        ).all()
        return [
            {
                "source": "weekly_feedback",
                "user_id": row[0],
                "week_start": row[1].isoformat(),
                "feedback_value": row[2],
            }
            for row in weekly_rows
        ]

    def _unavailable(self, source: str, reason: str) -> dict:
        return {
            "value": None,
            "status": "unavailable",
            "source": source,
            "reason": reason,
        }
