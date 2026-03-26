from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.core.config import settings
from app.schemas.capture_schema import SubmitFollowupRequest
from app.services.followup_service import FollowupService

router = APIRouter()


@router.post("/{followup_id}/submit")
def submit_followup(followup_id: str, payload: SubmitFollowupRequest, db: Session = Depends(get_db)) -> dict:
    try:
        result = FollowupService(db).submit_answer(settings.demo_user_id, followup_id, payload.answer_value)
        db.commit()
        return {"success": True, "data": result}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
