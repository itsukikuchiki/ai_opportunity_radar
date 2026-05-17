from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_user_id
from app.core.db import get_db
from app.schemas.analytics_schema import TrackEventRequest
from app.services.analytics_service import AnalyticsService

router = APIRouter(tags=["analytics"])


@router.post("/events")
def track_event(
    payload: TrackEventRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    AnalyticsService(db).track_event(
        user_id=user_id,
        event_name=payload.event_name,
        properties=payload.properties,
        numeric_value=payload.numeric_value,
    )
    return {"success": True}


@router.get("/metrics")
def metrics_summary(
    days: int = 30,
    db: Session = Depends(get_db),
) -> dict:
    safe_days = min(max(days, 1), 90)
    return {"success": True, "data": AnalyticsService(db).metrics_summary(days=safe_days)}
