from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.schemas.capture_schema import ConfirmSignalCardRequest, SubmitCaptureRequest
from app.services.capture_service import CaptureService
from app.services.classification_service import ClassificationService
from app.services.usage_service import UsageService
from app.repositories.capture_repository import CaptureRepository
from app.api.deps import get_user_id

router = APIRouter(tags=["captures"])


@router.post("")
def submit_capture(
    payload: SubmitCaptureRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        repository = CaptureRepository(db)

        result = CaptureService(
            repository,
            ClassificationService(),
            UsageService(db),
        ).submit_capture(
            user_id=user_id,
            content=payload.content,
            input_mode=payload.input_mode,
            tag_hint=payload.tag_hint,
            language=payload.language,
            timezone_name=payload.timezone,
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/recent")
def list_recent_captures(
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        repository = CaptureRepository(db)
        service = CaptureService(repository, ClassificationService(), UsageService(db))
        recent = service.list_recent_signal_cards(user_id=user_id, limit=200)
        return {"data": {"recent_signals": [item.model_dump() for item in recent]}}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.patch("/signal-cards/{signal_card_id}/confirmation")
def confirm_signal_card(
    signal_card_id: str,
    payload: ConfirmSignalCardRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        repository = CaptureRepository(db)
        card = repository.update_signal_card_confirmation(
            user_id=user_id,
            signal_card_id=signal_card_id,
            user_confirmation=payload.user_confirmation,
            user_correction=payload.user_correction_json,
            commit=True,
        )
        if card is None:
            raise HTTPException(status_code=404, detail="signal card not found")
        return {
            "data": {
                "signal_card_id": card.id,
                "user_confirmation": card.user_confirmation,
                "user_correction_json": card.user_correction_json,
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
