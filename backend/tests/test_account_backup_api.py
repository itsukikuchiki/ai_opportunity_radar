def test_apple_account_backup_roundtrip(client):
    auth_response = client.post(
        "/api/v1/auth/apple",
        json={
            "apple_user_id": "apple-sub-123",
            "identity_token": "sandbox-token",
            "local_user_id": "local-user-1",
            "device_id": "device-a",
        },
    )

    assert auth_response.status_code == 200
    auth_data = auth_response.json()["data"]
    assert auth_data["account_id"].startswith("acct_")
    assert auth_data["session_token"]
    assert auth_data["backup_enabled"] is True

    session_headers = {
        "X-Account-Session": auth_data["session_token"],
        "X-User-Id": "local-user-1",
    }

    bind_response = client.post(
        "/api/v1/account/bind-local-user",
        headers=session_headers,
        json={"local_user_id": "local-user-1"},
    )
    assert bind_response.status_code == 200
    assert bind_response.json()["data"]["bound"] is True

    bundle_payload = {
        "schema_version": 1,
        "backup_version": "2026-06-14T00:00:00Z",
        "device_id": "device-a",
        "tables": {
            "signal_cards": [
                {
                    "id": "sig-1",
                    "raw_text": "天气不错",
                    "privacy_level": "private",
                }
            ]
        },
        "counts": {"signal_cards": 1},
    }

    upload_response = client.post(
        "/api/v1/backup/upload",
        headers=session_headers,
        json={
            "schema_version": 1,
            "backup_version": bundle_payload["backup_version"],
            "device_id": "device-a",
            "payload": bundle_payload,
            "counts": bundle_payload["counts"],
        },
    )
    assert upload_response.status_code == 200
    upload_data = upload_response.json()["data"]
    assert upload_data["backup_version"] == bundle_payload["backup_version"]
    assert upload_data["payload"]["tables"]["signal_cards"][0]["id"] == "sig-1"

    latest_response = client.get(
        "/api/v1/backup/latest",
        headers=session_headers,
    )
    assert latest_response.status_code == 200
    latest_data = latest_response.json()["data"]
    assert latest_data["id"] == upload_data["id"]
    assert latest_data["counts"]["signal_cards"] == 1

    restore_response = client.post(
        "/api/v1/backup/restore-confirmed",
        headers=session_headers,
        json={"backup_id": upload_data["id"], "device_id": "device-b"},
    )
    assert restore_response.status_code == 200
    assert restore_response.json()["data"]["restored"] is True

    delete_response = client.delete(
        "/api/v1/backup",
        headers=session_headers,
    )
    assert delete_response.status_code == 200
    assert delete_response.json()["data"]["deleted"] == 1

    latest_after_delete = client.get(
        "/api/v1/backup/latest",
        headers=session_headers,
    )
    assert latest_after_delete.status_code == 200
    assert latest_after_delete.json()["data"] is None


def test_backup_requires_account_session(client):
    response = client.get("/api/v1/backup/latest")

    assert response.status_code == 401


def test_delete_account_removes_backups_and_invalidates_session(client):
    auth_response = client.post(
        "/api/v1/auth/apple",
        json={
            "apple_user_id": "apple-sub-delete",
            "local_user_id": "local-user-delete",
            "device_id": "device-delete",
        },
    )
    assert auth_response.status_code == 200
    session = auth_response.json()["data"]["session_token"]
    session_headers = {
        "X-Account-Session": session,
        "X-User-Id": "local-user-delete",
    }

    capture_response = client.post(
        "/api/v1/captures",
        headers={"X-User-Id": "local-user-delete"},
        json={
            "content": "今天想先删掉测试数据",
            "input_mode": "text",
            "language": "zh-Hans",
            "timezone": "Asia/Tokyo",
        },
    )
    assert capture_response.status_code == 200

    upload_response = client.post(
        "/api/v1/backup/upload",
        headers=session_headers,
        json={
            "schema_version": 1,
            "backup_version": "2026-06-14T01:00:00Z",
            "device_id": "device-delete",
            "payload": {"tables": {"signal_cards": []}},
            "counts": {"signal_cards": 0},
        },
    )
    assert upload_response.status_code == 200

    delete_response = client.delete(
        "/api/v1/account",
        headers=session_headers,
    )
    assert delete_response.status_code == 200
    delete_data = delete_response.json()["data"]
    assert delete_data["account_deleted"] is True
    assert delete_data["deleted"]["accounts"] == 1
    assert delete_data["deleted"]["account_aliases"] == 1
    assert delete_data["deleted"]["backup_bundles"] == 1
    assert delete_data["deleted"]["signal_cards"] >= 1

    latest_after_delete = client.get(
        "/api/v1/backup/latest",
        headers=session_headers,
    )
    assert latest_after_delete.status_code == 401

    recent_after_delete = client.get(
        "/api/v1/captures/recent",
        headers={"X-User-Id": "local-user-delete"},
    )
    assert recent_after_delete.status_code == 200
    assert recent_after_delete.json()["data"]["recent_signals"] == []
