from __future__ import annotations

import base64
import json
import time
from urllib import request as urllib_request
from urllib.error import URLError

from app.core.config import settings
from app.schemas.purchase_schema import VerifyPurchaseRequest, VerifyPurchaseResponse


class PurchaseService:
    pro_monthly_product_id = "jp.sunrise.signalpath.pro.monthly"
    pro_yearly_product_id = "jp.sunrise.signalpath.pro.yearly"
    pro_product_ids = {pro_monthly_product_id, pro_yearly_product_id}
    production_verify_url = "https://buy.itunes.apple.com/verifyReceipt"
    sandbox_verify_url = "https://sandbox.itunes.apple.com/verifyReceipt"

    def verify(self, payload: VerifyPurchaseRequest) -> VerifyPurchaseResponse:
        product_id = payload.product_id.strip()
        verification_data = payload.verification_data.strip()

        if product_id not in self.pro_product_ids:
            return self._response(
                verified=False,
                product_id=product_id,
                reason="unexpected_product_id",
            )

        if not verification_data:
            return self._response(
                verified=False,
                product_id=product_id,
                reason="missing_verification_data",
            )

        source = (payload.verification_source or "").lower()
        if "local" in source or self._looks_like_storekit_test_data(verification_data):
            return self._response(
                verified=True,
                product_id=product_id,
                environment="local_storekit",
            )

        if not settings.app_store_shared_secret:
            return self._response(
                verified=False,
                product_id=product_id,
                reason="missing_app_store_shared_secret",
            )

        return self._verify_with_apple(
            product_id=product_id,
            receipt_data=verification_data,
        )

    def _verify_with_apple(
        self,
        *,
        product_id: str,
        receipt_data: str,
    ) -> VerifyPurchaseResponse:
        response = self._post_receipt(self.production_verify_url, receipt_data)
        if response.get("status") == 21007:
            response = self._post_receipt(self.sandbox_verify_url, receipt_data)

        status = response.get("status")
        if status != 0:
            return self._response(
                verified=False,
                product_id=product_id,
                environment=response.get("environment"),
                reason=f"apple_status_{status}",
            )

        now_ms = int(time.time() * 1000)
        latest_receipts = response.get("latest_receipt_info") or []
        matching = [
            item
            for item in latest_receipts
            if item.get("product_id") == product_id
        ]
        if not matching:
            return self._response(
                verified=False,
                product_id=product_id,
                environment=response.get("environment"),
                reason="product_not_found_in_receipt",
            )

        active = any(
            int(item.get("expires_date_ms") or "0") > now_ms
            for item in matching
        )
        return self._response(
            verified=active,
            product_id=product_id,
            environment=response.get("environment"),
            reason=None if active else "subscription_expired",
        )

    def _post_receipt(self, url: str, receipt_data: str) -> dict:
        body = json.dumps(
            {
                "receipt-data": receipt_data,
                "password": settings.app_store_shared_secret,
                "exclude-old-transactions": True,
            }
        ).encode("utf-8")
        request = urllib_request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib_request.urlopen(request, timeout=8) as response:
                return json.loads(response.read().decode("utf-8"))
        except (OSError, URLError, json.JSONDecodeError) as exc:
            return {"status": "network_error", "error": str(exc)}

    def _looks_like_storekit_test_data(self, value: str) -> bool:
        try:
            decoded = base64.b64decode(value, validate=False)
        except Exception:
            return False
        lowered = decoded[:500].lower()
        return b"storekit" in lowered or b"xcode" in lowered

    def _response(
        self,
        *,
        verified: bool,
        product_id: str,
        environment: str | None = None,
        reason: str | None = None,
    ) -> VerifyPurchaseResponse:
        return VerifyPurchaseResponse(
            verified=verified,
            entitlement_active=verified,
            product_id=product_id,
            environment=environment,
            reason=reason,
        )
