from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import get_user_id
from app.schemas.self_review_schema import SelfReviewRequest
from app.services.self_review_service import SelfReviewService

router = APIRouter(tags=["self_review"])


@router.post("/self-review")
def generate_self_review(
    payload: SelfReviewRequest,
    user_id: str = Depends(get_user_id),
) -> dict:
    try:
        service = SelfReviewService()
        result = service.generate(payload)
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
