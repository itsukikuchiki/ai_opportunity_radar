from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.core.config import settings
from app.schemas.capture_schema import SubmitCaptureRequest
from app.services.capture_service import CaptureService

router = APIRouter()


@router.post("")
def submit_capture(payload: SubmitCaptureRequest, db: Session = Depends(get_db)) -> dict:
    try:
        result = CaptureService(db).submit_capture(
            user_id=settings.demo_user_id,
            content=payload.content,
            input_mode=payload.input_mode,
            tag_hint=payload.tag_hint,
        )
        return {"success": True, "data": result}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
