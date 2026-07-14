from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.api.deps import get_user_id
from app.core.db import get_db
from app.schemas.ai_schema import (
    CaptureReplyRequest,
    DeepWeeklyRequest,
    FollowupGenerateRequest,
    JourneyGenerateRequest,
    LightDialogRequest,
    MonthlyGenerateRequest,
    TodaySummaryRequest,
    WeeklyGenerateRequest,
)
from app.services.ai_orchestrator import AiOrchestrator
from app.services.ai_generation_service import AiGenerationService
from app.services.analytics_service import AnalyticsService
from app.services.legacy_telemetry_service import record_legacy_endpoint_call
from app.services.usage_service import UsageService

router = APIRouter(tags=["ai"])


def _record_ai_usage(
    *,
    db: Session,
    user_id: str,
    endpoint: str,
    request_payload: object,
    response_payload: object,
) -> None:
    profile = AiOrchestrator.from_endpoint(endpoint)
    try:
        usage = UsageService(db)
        usage.consume_quota(
            user_id=user_id,
            feature_key=profile.feature_key,
            local_date=date.today(),
            model_used=profile.model_label,
            source_event_id=None,
            commit=False,
        )
        usage.log_model_usage(
            user_id=user_id,
            feature_key=profile.feature_key,
            model_used=profile.model_label,
            request_payload=request_payload,
            response_payload=response_payload,
            metadata={"api_endpoint": endpoint},
            commit=False,
        )
        AnalyticsService(db).record_ai_usage(
            user_id=user_id,
            endpoint=profile.usage_endpoint,
            request_payload=request_payload,
            response_payload={
                "ai_layer": profile.layer,
                "product_role": profile.product_role,
                "payload": response_payload,
            },
            commit=False,
        )
        db.commit()
    except Exception:
        db.rollback()


@router.post("/capture-reply")
def generate_capture_reply(
    payload: CaptureReplyRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_capture_reply(payload.model_dump())
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="capture_reply",
            request_payload=payload.model_dump(),
            response_payload=result.model_dump(),
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/today-summary")
def generate_today_summary(
    payload: TodaySummaryRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_today_summary(payload)
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="today_summary",
            request_payload=payload.model_dump(),
            response_payload=result.model_dump(),
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/weekly-generate")
def generate_weekly_summary(
    payload: WeeklyGenerateRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_weekly_summary(payload)
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="weekly_generate",
            request_payload=payload.model_dump(),
            response_payload=result.model_dump(),
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/journey-generate")
def generate_journey_summary(
    payload: JourneyGenerateRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_journey_summary(payload)
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="journey_generate",
            request_payload=payload.model_dump(),
            response_payload=result.model_dump(),
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/light-dialog")
def generate_light_dialog(
    payload: LightDialogRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_light_dialog(payload)
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="light_dialog",
            request_payload=payload.model_dump(),
            response_payload=result.model_dump(),
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/deep-weekly")
def generate_deep_weekly(
    payload: DeepWeeklyRequest,
    request: Request,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    record_legacy_endpoint_call(
        db=db,
        counter_name="legacy_deep_weekly_endpoint_call_count",
        endpoint="/api/v1/ai/deep-weekly",
        request=request,
        user_id=user_id,
    )
    return _generate_weekly_reflect(payload=payload, user_id=user_id, db=db)


@router.post("/reflect-weekly")
def generate_reflect_weekly(
    payload: DeepWeeklyRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    return _generate_weekly_reflect(payload=payload, user_id=user_id, db=db)


def _generate_weekly_reflect(
    *,
    payload: DeepWeeklyRequest,
    user_id: str,
    db: Session,
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_deep_weekly(payload)
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="reflect_weekly",
            request_payload=payload.model_dump(),
            response_payload=result.model_dump(),
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/followup-question")
def generate_followup_question(
    payload: FollowupGenerateRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_followup_question(payload.model_dump())
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="followup_question",
            request_payload=payload.model_dump(),
            response_payload=result,
        )
        return {"data": result}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/monthly-generate")
def generate_monthly_summary(
    payload: MonthlyGenerateRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_monthly_summary(payload)
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="monthly_generate",
            request_payload=payload.model_dump(),
            response_payload=result.model_dump(),
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
