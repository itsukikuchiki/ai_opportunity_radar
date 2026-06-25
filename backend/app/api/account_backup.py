from __future__ import annotations

import base64
import json
import os
from datetime import datetime, timezone
from hashlib import sha256
from secrets import token_urlsafe
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.models import (
    Account,
    AccountAlias,
    AiUsage,
    AnalyticsEvent,
    BackupBundle,
    Capture,
    Desire,
    Experiment,
    FollowupAnswer,
    FollowupQuestion,
    Friction,
    ModelUsageLog,
    Opportunity,
    Pattern,
    QuotaGateEvent,
    RawMemory,
    SignalCard,
    UsageCounter,
    User,
    UserProfile,
    UserSubscription,
    WeeklyInsight,
)

router = APIRouter(tags=["account_backup"])


class AppleAuthRequest(BaseModel):
    apple_user_id: str | None = None
    identity_token: str | None = None
    local_user_id: str | None = None
    device_id: str | None = None


class BindLocalUserRequest(BaseModel):
    local_user_id: str


class BackupUploadRequest(BaseModel):
    schema_version: int = 1
    backup_version: str
    device_id: str | None = None
    payload: dict = Field(default_factory=dict)
    counts: dict = Field(default_factory=dict)


class RestoreConfirmedRequest(BaseModel):
    backup_id: str
    device_id: str | None = None


def _account_from_session(
    x_account_session: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Account:
    session = (x_account_session or "").strip()
    if not session:
        raise HTTPException(status_code=401, detail="Missing account session")
    account = db.scalars(
        select(Account).where(Account.session_token_hash == _hash(session))
    ).first()
    if account is None:
        raise HTTPException(status_code=401, detail="Invalid account session")
    return account


@router.post("/auth/apple")
def auth_apple(
    payload: AppleAuthRequest,
    db: Session = Depends(get_db),
) -> dict:
    stable_subject = _stable_apple_subject(payload)
    if not stable_subject:
        raise HTTPException(
            status_code=400,
            detail="Missing Apple user identifier",
        )

    apple_sub_hash = _hash(stable_subject)
    account = db.scalars(
        select(Account).where(Account.apple_sub_hash == apple_sub_hash)
    ).first()
    if account is None:
        account = Account(
            id=f"acct_{uuid4().hex[:16]}",
            apple_sub_hash=apple_sub_hash,
        )
        db.add(account)

    session_token = token_urlsafe(32)
    account.session_token_hash = _hash(session_token)
    if payload.local_user_id:
        _ensure_alias(db, account.id, payload.local_user_id)
    db.commit()

    return {
        "data": {
            "account_id": account.id,
            "session_token": session_token,
            "backup_enabled": True,
        }
    }


def _stable_apple_subject(payload: AppleAuthRequest) -> str:
    apple_user_id = (payload.apple_user_id or "").strip()
    identity_token = (payload.identity_token or "").strip()
    if identity_token.count(".") == 2:
        claims = _decode_apple_identity_claims(identity_token)
        subject = (claims.get("sub") or "").strip()
        if not subject:
            raise HTTPException(status_code=400, detail="Invalid Apple token subject")
        if apple_user_id and apple_user_id != subject:
            raise HTTPException(status_code=400, detail="Apple subject mismatch")
        return subject
    return apple_user_id or identity_token


def _decode_apple_identity_claims(identity_token: str) -> dict:
    try:
        payload_segment = identity_token.split(".")[1]
        padded = payload_segment + "=" * (-len(payload_segment) % 4)
        raw = base64.urlsafe_b64decode(padded.encode("utf-8"))
        claims = json.loads(raw.decode("utf-8"))
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid Apple identity token") from exc

    if claims.get("iss") != "https://appleid.apple.com":
        raise HTTPException(status_code=400, detail="Invalid Apple token issuer")

    expected_audience = os.getenv("APPLE_CLIENT_ID", "jp.sunrise.signalpath")
    audience = claims.get("aud")
    if isinstance(audience, list):
        valid_audience = expected_audience in audience
    else:
        valid_audience = audience == expected_audience
    if not valid_audience:
        raise HTTPException(status_code=400, detail="Invalid Apple token audience")

    return claims


@router.post("/account/bind-local-user")
def bind_local_user(
    payload: BindLocalUserRequest,
    account: Account = Depends(_account_from_session),
    db: Session = Depends(get_db),
) -> dict:
    alias = _ensure_alias(db, account.id, payload.local_user_id)
    db.commit()
    return {
        "data": {
            "account_id": account.id,
            "local_user_id": alias.local_user_id,
            "bound": True,
        }
    }


@router.post("/backup/upload")
def upload_backup(
    payload: BackupUploadRequest,
    account: Account = Depends(_account_from_session),
    db: Session = Depends(get_db),
) -> dict:
    bundle = BackupBundle(
        id=f"bkp_{uuid4().hex[:16]}",
        account_id=account.id,
        schema_version=payload.schema_version,
        backup_version=payload.backup_version,
        device_id=payload.device_id,
        payload=payload.payload,
        counts_json=payload.counts,
    )
    db.add(bundle)
    db.commit()
    db.refresh(bundle)
    return {"data": _backup_response(bundle)}


@router.get("/backup/latest")
def latest_backup(
    account: Account = Depends(_account_from_session),
    db: Session = Depends(get_db),
) -> dict:
    bundle = db.scalars(
        select(BackupBundle)
        .where(BackupBundle.account_id == account.id)
        .order_by(BackupBundle.created_at.desc())
    ).first()
    return {"data": None if bundle is None else _backup_response(bundle)}


@router.post("/backup/restore-confirmed")
def restore_confirmed(
    payload: RestoreConfirmedRequest,
    account: Account = Depends(_account_from_session),
    db: Session = Depends(get_db),
) -> dict:
    bundle = db.get(BackupBundle, payload.backup_id)
    if bundle is None or bundle.account_id != account.id:
        raise HTTPException(status_code=404, detail="Backup not found")
    bundle.restored_at = datetime.now(timezone.utc)
    bundle.restore_device_id = payload.device_id
    db.commit()
    return {"data": {"backup_id": bundle.id, "restored": True}}


@router.delete("/backup")
def delete_backups(
    account: Account = Depends(_account_from_session),
    db: Session = Depends(get_db),
) -> dict:
    bundles = db.scalars(
        select(BackupBundle).where(BackupBundle.account_id == account.id)
    ).all()
    deleted = len(bundles)
    for bundle in bundles:
        db.delete(bundle)
    db.commit()
    return {"data": {"deleted": deleted}}


@router.delete("/account")
def delete_account_and_user_data(
    account: Account = Depends(_account_from_session),
    db: Session = Depends(get_db),
    x_user_id: str | None = Header(default=None),
) -> dict:
    aliases = db.scalars(
        select(AccountAlias).where(AccountAlias.account_id == account.id)
    ).all()
    user_ids = {
        alias.local_user_id.strip()
        for alias in aliases
        if alias.local_user_id and alias.local_user_id.strip()
    }
    if x_user_id and x_user_id.strip():
        user_ids.add(x_user_id.strip())

    deleted = _delete_user_scoped_rows(db, user_ids)

    deleted["backup_bundles"] = db.execute(
        delete(BackupBundle).where(BackupBundle.account_id == account.id)
    ).rowcount or 0
    deleted["account_aliases"] = db.execute(
        delete(AccountAlias).where(AccountAlias.account_id == account.id)
    ).rowcount or 0
    deleted["accounts"] = db.execute(
        delete(Account).where(Account.id == account.id)
    ).rowcount or 0

    db.commit()
    return {
        "data": {
            "deleted": deleted,
            "local_user_ids": sorted(user_ids),
            "account_deleted": True,
        }
    }


def _ensure_alias(db: Session, account_id: str, local_user_id: str) -> AccountAlias:
    normalized = local_user_id.strip()
    if not normalized:
        raise HTTPException(status_code=400, detail="Missing local_user_id")
    alias = db.scalars(
        select(AccountAlias).where(
            AccountAlias.account_id == account_id,
            AccountAlias.local_user_id == normalized,
        )
    ).first()
    if alias is not None:
        return alias
    alias = AccountAlias(
        id=f"alias_{uuid4().hex[:16]}",
        account_id=account_id,
        local_user_id=normalized,
    )
    db.add(alias)
    return alias


def _backup_response(bundle: BackupBundle) -> dict:
    return {
        "id": bundle.id,
        "account_id": bundle.account_id,
        "schema_version": bundle.schema_version,
        "backup_version": bundle.backup_version,
        "device_id": bundle.device_id,
        "payload": bundle.payload,
        "counts": bundle.counts_json,
        "created_at": bundle.created_at.isoformat() if bundle.created_at else None,
        "updated_at": bundle.updated_at.isoformat() if bundle.updated_at else None,
        "restored_at": bundle.restored_at.isoformat() if bundle.restored_at else None,
    }


def _hash(value: str) -> str:
    return sha256(value.encode("utf-8")).hexdigest()


def _delete_user_scoped_rows(db: Session, user_ids: set[str]) -> dict[str, int]:
    if not user_ids:
        return {}

    deleted: dict[str, int] = {}
    user_scoped_models = [
        FollowupAnswer,
        FollowupQuestion,
        ModelUsageLog,
        QuotaGateEvent,
        UsageCounter,
        AiUsage,
        AnalyticsEvent,
        UserSubscription,
        WeeklyInsight,
        Experiment,
        Opportunity,
        Desire,
        Friction,
        Pattern,
        SignalCard,
        RawMemory,
        Capture,
        UserProfile,
    ]
    for model in user_scoped_models:
        result = db.execute(delete(model).where(model.user_id.in_(user_ids)))
        deleted[model.__tablename__] = result.rowcount or 0
    result = db.execute(delete(User).where(User.id.in_(user_ids)))
    deleted[User.__tablename__] = result.rowcount or 0
    return deleted
