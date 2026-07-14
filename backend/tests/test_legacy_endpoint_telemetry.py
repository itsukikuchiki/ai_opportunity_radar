from __future__ import annotations

from sqlalchemy import select


def test_reflect_weekly_canonical_endpoint_does_not_increment_legacy_counter(client):
    response = client.post(
        "/api/v1/ai/reflect-weekly",
        headers=_headers(
            user_id="test-user-reflect-weekly-current",
            client_version="4.1.0",
            platform="ios",
        ),
        json=_weekly_reflect_payload(),
    )

    assert response.status_code == 200, response.text
    assert _telemetry_rows() == []


def test_capture_legacy_telemetry_does_not_store_signal_text(client):
    raw_signal = "PRIVATE_RAW_SIGNAL_TEXT_SHOULD_NEVER_ENTER_TELEMETRY"
    response = client.post(
        "/api/v1/captures",
        headers=_headers(
            user_id="test-user-capture-telemetry-privacy",
            client_version="3.9.0",
            platform="ios",
        ),
        json={
            "content": raw_signal,
            "input_mode": "quick_capture",
            "client_id": "client-telemetry-privacy-1",
        },
    )

    assert response.status_code == 200, response.text
    rows = _telemetry_rows("legacy_captures_endpoint_call_count")
    assert len(rows) == 1
    telemetry = rows[0]

    assert telemetry.endpoint == "/api/v1/captures"
    assert telemetry.client_version == "3.9.0"
    assert telemetry.platform == "ios"
    assert telemetry.user_id_hash is not None
    assert raw_signal not in {
        value
        for value in telemetry.__dict__.values()
        if isinstance(value, str)
    }


def test_legacy_telemetry_keeps_client_version_and_platform_dimensions(client):
    first = client.get(
        "/api/v1/opportunities",
        headers=_headers(
            user_id="test-user-opportunities-ios",
            client_version="3.8.legacy",
            platform="ios",
        ),
    )
    second = client.get(
        "/api/v1/opportunities",
        headers=_headers(
            user_id="test-user-opportunities-android",
            client_version="3.7.legacy",
            platform="android",
        ),
    )

    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text
    rows = _telemetry_rows("legacy_opportunities_endpoint_call_count")

    dimensions = {(row.client_version, row.platform) for row in rows}
    assert ("3.8.legacy", "ios") in dimensions
    assert ("3.7.legacy", "android") in dimensions
    assert len({row.user_id_hash for row in rows}) == 2


def test_account_auth_and_backup_telemetry_are_counted_separately(client):
    auth_response = client.post(
        "/api/v1/auth/apple",
        headers=_headers(
            user_id="test-user-account-backup-telemetry",
            client_version="3.9.legacy",
            platform="ios",
        ),
        json={
            "apple_user_id": "apple-telemetry-subject",
            "local_user_id": "test-user-account-backup-telemetry",
            "device_id": "device-auth",
        },
    )
    assert auth_response.status_code == 200, auth_response.text
    session_token = auth_response.json()["data"]["session_token"]
    account_headers = {
        **_headers(
            user_id="test-user-account-backup-telemetry",
            client_version="3.9.legacy",
            platform="ios",
        ),
        "X-Account-Session": session_token,
    }

    bind_response = client.post(
        "/api/v1/account/bind-local-user",
        headers=account_headers,
        json={"local_user_id": "test-user-account-backup-telemetry"},
    )
    assert bind_response.status_code == 200, bind_response.text

    backup_response = client.post(
        "/api/v1/backup/upload",
        headers=account_headers,
        json={
            "schema_version": 1,
            "backup_version": "2026-07-05T00:00:00Z",
            "device_id": "device-backup",
            "payload": {"summary": "legacy backup payload"},
            "counts": {"signal_cards": 1},
        },
    )
    assert backup_response.status_code == 200, backup_response.text

    auth_rows = _telemetry_rows("legacy_auth_apple_endpoint_call_count")
    account_rows = _telemetry_rows("legacy_account_endpoint_call_count")
    backup_rows = _telemetry_rows("legacy_backup_endpoint_call_count")

    assert [row.endpoint for row in auth_rows] == ["/api/v1/auth/apple"]
    assert [row.endpoint for row in account_rows] == [
        "/api/v1/account/bind-local-user"
    ]
    assert [row.endpoint for row in backup_rows] == ["/api/v1/backup/upload"]
    assert auth_rows[0].account_id_hash is not None
    assert account_rows[0].account_id_hash == auth_rows[0].account_id_hash
    assert backup_rows[0].account_id_hash == auth_rows[0].account_id_hash


def _headers(
    *,
    user_id: str,
    client_version: str,
    platform: str,
) -> dict[str, str]:
    return {
        "X-User-Id": user_id,
        "X-Client-Version": client_version,
        "X-Platform": platform,
    }


def _weekly_reflect_payload() -> dict:
    return {
        "week_start": "2026-07-01",
        "week_end": "2026-07-07",
        "key_insight": "本周能量变化开始影响实验强度。",
        "patterns": [
            {
                "name": "能量下降",
                "summary": "低能量日更适合轻量实验。",
            }
        ],
        "frictions": [
            {
                "name": "会议后恢复不足",
                "summary": "连续会议后行动强度需要降低。",
            }
        ],
        "best_action": "下周优先尝试低强度实验。",
        "chart_data": [
            {
                "date": "2026-07-03",
                "signal_count": 3,
                "mood_score": -0.3,
                "friction_score": 0.6,
                "has_positive_signal": False,
            }
        ],
        "focus_area": "energy_budget",
    }


def _telemetry_rows(counter_name: str | None = None):
    from app.core.db import SessionLocal
    from app.models import LegacyEndpointTelemetry

    db = SessionLocal()
    try:
        stmt = select(LegacyEndpointTelemetry).order_by(
            LegacyEndpointTelemetry.created_at,
            LegacyEndpointTelemetry.endpoint,
        )
        if counter_name is not None:
            stmt = stmt.where(LegacyEndpointTelemetry.counter_name == counter_name)
        return db.scalars(stmt).all()
    finally:
        db.close()
