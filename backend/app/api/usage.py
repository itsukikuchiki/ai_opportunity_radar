from __future__ import annotations

from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_user_id
from app.core.db import get_db
from app.models import UsageCounter, UserSubscription
from app.repositories.core_repository import ensure_demo_user
from app.services.ai_orchestrator import AiOrchestrator
from app.services.usage_service import UsageService

router = APIRouter(tags=["usage"])


@router.get("/summary")
def usage_summary(
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        ensure_demo_user(db, user_id)
        entitlement = _entitlement(db, user_id)
        limits = (
            UsageService.pro_limits
            if entitlement == "pro"
            else UsageService.free_limits
        )
        today = date.today()
        items = []
        for feature_key, (period_type, limit_value) in limits.items():
            profile = AiOrchestrator.from_feature_key(feature_key)
            period_start = _period_start(today, period_type)
            counter = db.scalars(
                select(UsageCounter).where(
                    UsageCounter.user_id == user_id,
                    UsageCounter.feature_key == feature_key,
                    UsageCounter.period_type == period_type,
                    UsageCounter.period_start == period_start,
                )
            ).first()
            used = counter.count if counter else 0
            items.append(
                {
                    "feature_key": feature_key,
                    "ai_layer": profile.layer,
                    "product_role": profile.product_role,
                    "user_participation": profile.user_participation,
                    "period_type": period_type,
                    "period_start": period_start,
                    "used": used,
                    "limit": limit_value,
                    "remaining": None if limit_value is None else max(0, limit_value - used),
                    "entitlement": entitlement,
                }
            )
        return {"data": {"entitlement": entitlement, "quotas": items}}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


def _entitlement(db: Session, user_id: str) -> str:
    subscription = db.get(UserSubscription, user_id)
    if subscription and subscription.status == "active":
        return "pro"
    return "free"


def _period_start(local_date: date, period_type: str) -> str:
    if period_type == "daily":
        return local_date.isoformat()
    if period_type == "weekly":
        return (local_date - timedelta(days=local_date.weekday())).isoformat()
    if period_type == "monthly":
        return local_date.replace(day=1).isoformat()
    return local_date.isoformat()
