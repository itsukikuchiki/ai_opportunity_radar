from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from time import perf_counter
from typing import Any
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ModelUsageLog, QuotaGateEvent, UsageCounter, UserSubscription
from app.repositories.core_repository import ensure_demo_user


@dataclass(frozen=True)
class QuotaDecision:
    allowed: bool
    decision: str
    entitlement: str
    period_type: str
    period_start: str
    limit_value: int | None
    used_value: int


class UsageService:
    free_limits = {
        "today_high_quality_reply": ("daily", 3),
        "weekly_basic": ("weekly", 1),
        "life_experiment_light": ("weekly", 1),
    }

    pro_limits = {
        "today_high_quality_reply": ("monthly", 150),
        "light_dialogue_turn": ("monthly", 60),
        "deep_weekly": ("monthly", 4),
        "journey_monthly_life_map": ("monthly", 2),
        "misunderstanding_check": ("monthly", 12),
        "gpt55_deep_upgrade": ("monthly", 10),
    }

    def __init__(self, db: Session):
        self.db = db

    def check_quota(
        self,
        *,
        user_id: str,
        feature_key: str,
        local_date: date,
        source_event_id: str | None = None,
        commit: bool = True,
    ) -> QuotaDecision:
        ensure_demo_user(self.db, user_id)
        entitlement = self._entitlement(user_id)
        limits = self.pro_limits if entitlement == "pro" else self.free_limits
        period_type, limit_value = limits.get(feature_key, ("monthly", None))
        period_start = self._period_start(local_date, period_type)

        counter = self._get_counter(
            user_id=user_id,
            feature_key=feature_key,
            period_type=period_type,
            period_start=period_start,
        )
        used_value = counter.count if counter else 0
        allowed = limit_value is None or used_value < limit_value
        decision = "allowed" if allowed else "quota_exceeded"

        self.db.add(QuotaGateEvent(
            id=str(uuid4()),
            user_id=user_id,
            feature_key=feature_key,
            entitlement=entitlement,
            period_type=period_type,
            period_start=period_start,
            limit_value=limit_value,
            used_value=used_value,
            decision=decision,
            source_event_id=source_event_id,
            metadata_json={},
        ))
        if commit:
            self.db.commit()
        else:
            self.db.flush()

        return QuotaDecision(
            allowed=allowed,
            decision=decision,
            entitlement=entitlement,
            period_type=period_type,
            period_start=period_start,
            limit_value=limit_value,
            used_value=used_value,
        )

    def consume_quota(
        self,
        *,
        user_id: str,
        feature_key: str,
        local_date: date,
        model_used: str | None,
        source_event_id: str | None,
        token_input: int = 0,
        token_output: int = 0,
        token_cached_input: int = 0,
        commit: bool = True,
    ) -> UsageCounter:
        entitlement = self._entitlement(user_id)
        limits = self.pro_limits if entitlement == "pro" else self.free_limits
        period_type, _ = limits.get(feature_key, ("monthly", None))
        period_start = self._period_start(local_date, period_type)
        counter = self._get_counter(
            user_id=user_id,
            feature_key=feature_key,
            period_type=period_type,
            period_start=period_start,
        )
        if counter is None:
            counter = UsageCounter(
                id=str(uuid4()),
                user_id=user_id,
                feature_key=feature_key,
                period_type=period_type,
                period_start=period_start,
                count=0,
                token_input=0,
                token_output=0,
                token_cached_input=0,
                model_used=model_used,
                source_event_id=source_event_id,
            )
            self.db.add(counter)

        counter.count += 1
        counter.token_input += token_input
        counter.token_output += token_output
        counter.token_cached_input += token_cached_input
        counter.model_used = model_used
        counter.source_event_id = source_event_id
        if commit:
            self.db.commit()
        else:
            self.db.flush()
        return counter

    def log_model_usage(
        self,
        *,
        user_id: str,
        feature_key: str,
        model_used: str | None,
        parser_version: str | None = None,
        prompt_version: str | None = None,
        request_payload: object | None = None,
        response_payload: object | None = None,
        fallback_used: bool = False,
        quota_decision: str = "allowed",
        cache_hit: bool = False,
        source_event_id: str | None = None,
        started_at: float | None = None,
        metadata: dict[str, Any] | None = None,
        commit: bool = True,
    ) -> ModelUsageLog:
        input_tokens = self._estimate_tokens(request_payload)
        output_tokens = self._estimate_tokens(response_payload)
        latency_ms = None
        if started_at is not None:
            latency_ms = int((perf_counter() - started_at) * 1000)

        log = ModelUsageLog(
            id=str(uuid4()),
            user_id=user_id,
            feature_key=feature_key,
            model_used=model_used,
            parser_version=parser_version,
            prompt_version=prompt_version,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            cached_input_tokens=0,
            latency_ms=latency_ms,
            fallback_used=fallback_used,
            quota_decision=quota_decision,
            cache_hit=cache_hit,
            source_event_id=source_event_id,
            metadata_json=self._privacy_safe_metadata(metadata or {}),
            estimated_cost_usd=0.0,
        )
        self.db.add(log)
        if commit:
            self.db.commit()
        else:
            self.db.flush()
        return log

    def _get_counter(
        self,
        *,
        user_id: str,
        feature_key: str,
        period_type: str,
        period_start: str,
    ) -> UsageCounter | None:
        stmt = select(UsageCounter).where(
            UsageCounter.user_id == user_id,
            UsageCounter.feature_key == feature_key,
            UsageCounter.period_type == period_type,
            UsageCounter.period_start == period_start,
        )
        return self.db.scalars(stmt).first()

    def _entitlement(self, user_id: str) -> str:
        subscription = self.db.get(UserSubscription, user_id)
        if subscription and subscription.status == "active":
            return "pro"
        return "free"

    def _period_start(self, local_date: date, period_type: str) -> str:
        if period_type == "daily":
            return local_date.isoformat()
        if period_type == "weekly":
            return (local_date - timedelta(days=local_date.weekday())).isoformat()
        if period_type == "monthly":
            return local_date.replace(day=1).isoformat()
        return local_date.isoformat()

    def _estimate_tokens(self, payload: object | None) -> int:
        if payload is None:
            return 0
        text = json.dumps(payload, ensure_ascii=False, default=str)
        return max(1, len(text) // 4)

    def _privacy_safe_metadata(self, metadata: dict[str, Any]) -> dict[str, Any]:
        blocked = {"raw_text", "content", "prompt", "user_text"}
        return {key: value for key, value in metadata.items() if key not in blocked}
