from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.schemas.capture_schema import SubmitCaptureRequest
from app.services.capture_service import CaptureService
from app.services.classification_service import ClassificationService
from app.repositories.capture_repository import CaptureRepository

router = APIRouter(tags=["captures"])


@router.post("")
def submit_capture(
    payload: SubmitCaptureRequest,
    db: Session = Depends(get_db),
) -> dict:
    try:
        repository = CaptureRepository(db)

        result = CaptureService(
            repository,
            ClassificationService(),
        ).submit_capture(
            user_id="demo-user",
            content=payload.content,
            input_mode=payload.input_mode,
            tag_hint=payload.tag_hint,
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
