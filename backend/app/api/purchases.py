from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_user_id
from app.core.db import get_db
from app.schemas.purchase_schema import VerifyPurchaseRequest
from app.services.purchase_service import PurchaseService

router = APIRouter(tags=["purchases"])


@router.post("/verify")
def verify_purchase(
    payload: VerifyPurchaseRequest,
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    result = PurchaseService(db=db).verify(payload, user_id=user_id)
    return {"success": True, "data": result.model_dump()}
