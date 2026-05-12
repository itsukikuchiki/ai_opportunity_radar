from fastapi import APIRouter

from app.schemas.purchase_schema import VerifyPurchaseRequest
from app.services.purchase_service import PurchaseService

router = APIRouter(tags=["purchases"])


@router.post("/verify")
def verify_purchase(payload: VerifyPurchaseRequest) -> dict:
    result = PurchaseService().verify(payload)
    return {"success": True, "data": result.model_dump()}
