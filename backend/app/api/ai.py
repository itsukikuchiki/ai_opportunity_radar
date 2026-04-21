from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import get_user_id
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

router = APIRouter(tags=["ai"])


@router.post("/capture-reply")
def generate_capture_reply(
    payload: CaptureReplyRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_capture_reply(payload.model_dump())
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/today-summary")
def generate_today_summary(
    payload: TodaySummaryRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_today_summary(payload)
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/weekly-generate")
def generate_weekly_summary(
    payload: WeeklyGenerateRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_weekly_summary(payload)
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/journey-generate")
def generate_journey_summary(
    payload: JourneyGenerateRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_journey_summary(payload)
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/opportunity-explanation")
def generate_opportunity_explanation(
    payload: OpportunityExplanationRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_opportunity_explanation(payload.model_dump())
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))




@router.post("/light-dialog")
def generate_light_dialog(
    payload: LightDialogRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_light_dialog(payload)
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/deep-weekly")
def generate_deep_weekly(
    payload: DeepWeeklyRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_deep_weekly(payload)
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
@router.post("/followup-question")
def generate_followup_question(
    payload: FollowupGenerateRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_followup_question(payload.model_dump())
        return {"data": result}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/monthly-generate")
def generate_monthly_summary(
    payload: MonthlyGenerateRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = AiGenerationService()
        result = service.generate_monthly_summary(payload)
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
