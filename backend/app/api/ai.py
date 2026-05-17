from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
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
    OpportunityExplanationRequest,
    TodaySummaryRequest,
    WeeklyGenerateRequest,
)
from app.services.ai_generation_service import AiGenerationService
from app.services.analytics_service import AnalyticsService

router = APIRouter(tags=["ai"])


def _record_ai_usage(
    *,
    db: Session,
    user_id: str,
    endpoint: str,
    request_payload: object,
    response_payload: object,
) -> None:
    try:
        AnalyticsService(db).record_ai_usage(
            user_id=user_id,
            endpoint=endpoint,
            request_payload=request_payload,
            response_payload=response_payload,
        )
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


@router.post("/opportunity-explanation")
def generate_opportunity_explanation(
    payload: OpportunityExplanationRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_opportunity_explanation(payload.model_dump())
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="opportunity_explanation",
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
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_deep_weekly(payload)
        _record_ai_usage(
            db=db,
            user_id=user_id,
            endpoint="deep_weekly",
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
