from pydantic import BaseModel


class VerifyPurchaseRequest(BaseModel):
    product_id: str
    verification_data: str
    verification_source: str | None = None
    transaction_date: str | None = None


class VerifyPurchaseResponse(BaseModel):
    verified: bool
    entitlement_active: bool
    product_id: str
    environment: str | None = None
    reason: str | None = None
