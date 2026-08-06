from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_user_id
from app.core.db import get_db
from app.schemas.capture_schema import SubmitFollowupRequest
from app.services.followup_service import FollowupService

router = APIRouter()


@router.post("/{followup_id}/submit")
def submit_followup(
    followup_id: str,
    payload: SubmitFollowupRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        result = FollowupService(db).submit_answer(
            user_id,
            followup_id,
            payload.answer_value,
        )
        db.commit()
        return {"success": True, "data": result}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
