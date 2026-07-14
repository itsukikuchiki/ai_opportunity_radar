from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.api.errors import api_error, error_message
from app.core.db import get_db
from app.schemas.capture_schema import (
    ConfirmSignalCardRequest,
    SignalCardDeleteRequest,
    SubmitCaptureRequest,
)
from app.services.capture_service import CaptureService
from app.services.classification_service import ClassificationService
from app.services.usage_service import UsageService
from app.services.legacy_telemetry_service import record_legacy_endpoint_call
from app.repositories.capture_repository import CaptureRepository
from app.api.deps import get_user_id

router = APIRouter(tags=["captures"])


@router.post("")
def submit_capture(
    payload: SubmitCaptureRequest,
    request: Request,
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
            client_id=payload.client_id,
            raw_payload_json=payload.raw_payload_json,
        )
        record_legacy_endpoint_call(
            db=db,
            counter_name="legacy_captures_endpoint_call_count",
            endpoint="/api/v1/captures",
            request=request,
            user_id=user_id,
        )
        return {"data": result.model_dump()}
    except Exception as e:
        raise api_error(
            status_code=400,
            code="CAPTURE_SUBMIT_FAILED",
            message=error_message(e),
        )


@router.get("/recent")
def list_recent_captures(
    request: Request,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        repository = CaptureRepository(db)
        service = CaptureService(repository, ClassificationService(), UsageService(db))
        recent = service.list_recent_signal_cards(user_id=user_id, limit=200)
        record_legacy_endpoint_call(
            db=db,
            counter_name="legacy_captures_endpoint_call_count",
            endpoint="/api/v1/captures/recent",
            request=request,
            user_id=user_id,
        )
        return {"data": {"recent_signals": [item.model_dump() for item in recent]}}
    except Exception as e:
        raise api_error(
            status_code=400,
            code="CAPTURE_RECENT_FAILED",
            message=error_message(e),
        )


@router.patch("/signal-cards/{signal_card_id}/confirmation")
def confirm_signal_card(
    signal_card_id: str,
    payload: ConfirmSignalCardRequest,
    request: Request,
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
            raise api_error(
                status_code=404,
                code="SIGNAL_CARD_NOT_FOUND",
                message="signal card not found",
            )
        record_legacy_endpoint_call(
            db=db,
            counter_name="legacy_captures_endpoint_call_count",
            endpoint="/api/v1/captures/signal-cards/{signal_card_id}/confirmation",
            request=request,
            user_id=user_id,
        )
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
        raise api_error(
            status_code=400,
            code="SIGNAL_CARD_CONFIRMATION_FAILED",
            message=error_message(e),
        )


@router.delete("/signal-cards/{signal_card_id}")
def delete_signal_card(
    signal_card_id: str,
    request: Request,
    payload: SignalCardDeleteRequest | None = None,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        repository = CaptureRepository(db)
        card = repository.soft_delete_signal_card(
            user_id=user_id,
            signal_card_id=signal_card_id,
            reason=payload.reason if payload else "user_deleted",
            commit=True,
        )
        if card is None:
            raise api_error(
                status_code=404,
                code="SIGNAL_CARD_NOT_FOUND",
                message="signal card not found",
            )
        record_legacy_endpoint_call(
            db=db,
            counter_name="legacy_captures_endpoint_call_count",
            endpoint="/api/v1/captures/signal-cards/{signal_card_id}",
            request=request,
            user_id=user_id,
        )
        return {
            "data": {
                "signal_card_id": card.id,
                "deleted_at": card.deleted_at,
                "deletion_reason": card.deletion_reason,
                "tombstone_version": card.tombstone_version,
                "status": "deleted",
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise api_error(
            status_code=400,
            code="SIGNAL_CARD_DELETE_FAILED",
            message=error_message(e),
        )


@router.post("/signal-cards/{signal_card_id}/restore")
def restore_signal_card(
    signal_card_id: str,
    request: Request,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        repository = CaptureRepository(db)
        card = repository.restore_signal_card(
            user_id=user_id,
            signal_card_id=signal_card_id,
            commit=True,
        )
        if card is None:
            raise api_error(
                status_code=404,
                code="SIGNAL_CARD_NOT_FOUND",
                message="signal card not found",
            )
        record_legacy_endpoint_call(
            db=db,
            counter_name="legacy_captures_endpoint_call_count",
            endpoint="/api/v1/captures/signal-cards/{signal_card_id}/restore",
            request=request,
            user_id=user_id,
        )
        return {
            "data": {
                "signal_card_id": card.id,
                "deleted_at": card.deleted_at,
                "restored_at": card.restored_at,
                "tombstone_version": card.tombstone_version,
                "status": "restored",
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise api_error(
            status_code=400,
            code="SIGNAL_CARD_RESTORE_FAILED",
            message=error_message(e),
        )
