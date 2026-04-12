from __future__ import annotations

from fastapi import APIRouter

from app.schemas.ai_schema import (
    CaptureReplyRequest,
    JourneyGenerateRequest,
    TodaySummaryRequest,
    WeeklyGenerateRequest,
)
from app.schemas.common import ApiResponse
from app.services.ai_generation_service import AiGenerationService

router = APIRouter()
service = AiGenerationService()


@router.post("/capture-reply", response_model=ApiResponse)
def generate_capture_reply(request: CaptureReplyRequest) -> ApiResponse:
    result = service.generate_capture_reply(request.model_dump())
    return ApiResponse(success=True, data=result.model_dump())


@router.post("/today-summary", response_model=ApiResponse)
def generate_today_summary(request: TodaySummaryRequest) -> ApiResponse:
    result = service.generate_today_summary(request)
    return ApiResponse(success=True, data=result.model_dump())


@router.post("/weekly-generate", response_model=ApiResponse)
def generate_weekly_summary(request: WeeklyGenerateRequest) -> ApiResponse:
    result = service.generate_weekly_summary(request)
    return ApiResponse(success=True, data=result.model_dump())


@router.post("/journey-generate", response_model=ApiResponse)
def generate_journey_summary(request: JourneyGenerateRequest) -> ApiResponse:
    result = service.generate_journey_summary(request)
    return ApiResponse(success=True, data=result.model_dump())
