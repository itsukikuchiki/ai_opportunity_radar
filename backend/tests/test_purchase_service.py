import base64

from sqlalchemy import func, select

from app.schemas.purchase_schema import VerifyPurchaseRequest
from app.services.purchase_service import PurchaseService


def _headers(user_id: str) -> dict[str, str]:
    return {"Content-Type": "application/json", "X-User-Id": user_id}


def _local_storekit_receipt() -> str:
    return base64.b64encode(b"Xcode StoreKit local test receipt").decode("ascii")


def test_storekit2_jws_is_not_sent_to_legacy_receipt_verifier(monkeypatch):
    service = PurchaseService()
    apple_calls = 0

    def fail_if_called(*, product_id: str, receipt_data: str):
        nonlocal apple_calls
        apple_calls += 1
        raise AssertionError("StoreKit 2 JWS must not reach verifyReceipt")

    monkeypatch.setattr(service, "_verify_with_apple", fail_if_called)

    response = service.verify(
        VerifyPurchaseRequest(
            product_id=PurchaseService.pro_yearly_product_id,
            verification_data="header.payload.signature",
            verification_source="storekit2_jws",
        )
    )

    assert response.verified is False
    assert response.entitlement_active is False
    assert response.reason == "unsupported_storekit2_verification_data"
    assert apple_calls == 0


def test_storekit2_local_entitlement_is_not_server_verified_from_source_name(
    monkeypatch,
):
    service = PurchaseService()
    apple_calls = 0

    def fail_if_called(*, product_id: str, receipt_data: str):
        nonlocal apple_calls
        apple_calls += 1
        raise AssertionError("Local StoreKit entitlement is not an App Receipt")

    monkeypatch.setattr(service, "_verify_with_apple", fail_if_called)

    response = service.verify(
        VerifyPurchaseRequest(
            product_id=PurchaseService.pro_monthly_product_id,
            verification_data="not-an-app-receipt",
            verification_source="storekit2_local_verified",
        )
    )

    assert response.verified is False
    assert response.reason == "unsupported_storekit2_verification_data"
    assert apple_calls == 0


def test_non_authoritative_verification_failure_preserves_active_subscription(
    client,
):
    from app.core.db import SessionLocal
    from app.models import UserSubscription

    user_id = "purchase-preserve-active"
    first = client.post(
        "/api/v1/purchases/verify",
        headers=_headers(user_id),
        json={
            "product_id": PurchaseService.pro_yearly_product_id,
            "verification_data": _local_storekit_receipt(),
            "verification_source": "app_receipt",
            "transaction_date": "2026-07-13T10:00:00Z",
        },
    )
    assert first.status_code == 200, first.text
    assert first.json()["data"]["entitlement_active"] is True

    failed = client.post(
        "/api/v1/purchases/verify",
        headers=_headers(user_id),
        json={
            "product_id": PurchaseService.pro_yearly_product_id,
            "verification_data": "header.payload.signature",
            "verification_source": "storekit2_jws",
        },
    )
    assert failed.status_code == 200, failed.text
    assert failed.json()["data"]["entitlement_active"] is False
    assert failed.json()["data"]["reason"] == (
        "unsupported_storekit2_verification_data"
    )

    db = SessionLocal()
    try:
        subscription = db.get(UserSubscription, user_id)
        assert subscription is not None
        assert subscription.status == "active"
        assert subscription.environment == "local_storekit"
        assert subscription.transaction_date == "2026-07-13T10:00:00Z"
    finally:
        db.close()


def test_repeated_purchase_verification_is_idempotent_for_entitlement_row(client):
    from app.core.db import SessionLocal
    from app.models import UserSubscription

    user_id = "purchase-idempotent"
    payload = {
        "product_id": PurchaseService.pro_monthly_product_id,
        "verification_data": _local_storekit_receipt(),
        "verification_source": "app_receipt",
        "transaction_date": "2026-07-13T11:00:00Z",
    }
    first = client.post(
        "/api/v1/purchases/verify",
        headers=_headers(user_id),
        json=payload,
    )
    second = client.post(
        "/api/v1/purchases/verify",
        headers=_headers(user_id),
        json=payload,
    )
    assert first.status_code == second.status_code == 200
    assert first.json()["data"] == second.json()["data"]

    db = SessionLocal()
    try:
        count = db.scalar(
            select(func.count()).select_from(UserSubscription).where(
                UserSubscription.user_id == user_id
            )
        )
        subscription = db.get(UserSubscription, user_id)
    finally:
        db.close()

    assert count == 1
    assert subscription is not None
    assert subscription.status == "active"
    assert subscription.product_id == PurchaseService.pro_monthly_product_id


def test_only_matching_environment_authoritative_failure_can_revoke(client):
    from app.core.db import SessionLocal
    from app.models import UserSubscription
    from app.services.analytics_service import AnalyticsService

    user_id = "purchase-authoritative-revocation"
    db = SessionLocal()
    try:
        analytics = AnalyticsService(db)
        analytics.upsert_subscription(
            user_id=user_id,
            product_id=PurchaseService.pro_yearly_product_id,
            verified=True,
            environment="Sandbox",
            reason=None,
            transaction_date="2026-07-13T12:00:00Z",
        )
        analytics.upsert_subscription(
            user_id=user_id,
            product_id=PurchaseService.pro_yearly_product_id,
            verified=False,
            environment="Production",
            reason="subscription_expired",
            transaction_date=None,
        )
        assert db.get(UserSubscription, user_id).status == "active"

        analytics.upsert_subscription(
            user_id=user_id,
            product_id=PurchaseService.pro_yearly_product_id,
            verified=False,
            environment="Sandbox",
            reason="subscription_expired",
            transaction_date=None,
        )
        assert db.get(UserSubscription, user_id).status == "inactive"
    finally:
        db.close()
