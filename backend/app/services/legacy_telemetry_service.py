from __future__ import annotations

from hashlib import sha256
from uuid import uuid4

from fastapi import Request
from sqlalchemy.orm import Session

from app.models.analytics import LegacyEndpointTelemetry


class LegacyTelemetryService:
    def __init__(self, db: Session):
        self.db = db

    def record_endpoint_call(
        self,
        *,
        counter_name: str,
        endpoint: str,
        request: Request | None = None,
        user_id: str | None = None,
        account_id: str | None = None,
        commit: bool = True,
    ) -> None:
        telemetry = LegacyEndpointTelemetry(
            id=str(uuid4()),
            counter_name=counter_name,
            endpoint=endpoint,
            client_version=_header(request, "x-client-version"),
            platform=_header(request, "x-platform"),
            user_id_hash=_hash_optional(user_id),
            account_id_hash=_hash_optional(account_id),
        )
        self.db.add(telemetry)
        if commit:
            self.db.commit()


def record_legacy_endpoint_call(
    *,
    db: Session,
    counter_name: str,
    endpoint: str,
    request: Request | None = None,
    user_id: str | None = None,
    account_id: str | None = None,
) -> None:
    try:
        LegacyTelemetryService(db).record_endpoint_call(
            counter_name=counter_name,
            endpoint=endpoint,
            request=request,
            user_id=user_id,
            account_id=account_id,
        )
    except Exception:
        db.rollback()


def _header(request: Request | None, name: str) -> str | None:
    if request is None:
        return None
    value = request.headers.get(name)
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


def _hash_optional(value: str | None) -> str | None:
    normalized = (value or "").strip()
    if not normalized:
        return None
    return sha256(normalized.encode("utf-8")).hexdigest()
