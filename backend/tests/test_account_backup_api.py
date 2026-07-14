from datetime import datetime, timezone


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

    from sqlalchemy import select

    from app.core.db import SessionLocal
    from app.models import LegacyEndpointTelemetry

    db = SessionLocal()
    try:
        backup_rows = db.scalars(
            select(LegacyEndpointTelemetry).where(
                LegacyEndpointTelemetry.counter_name
                == "legacy_backup_endpoint_call_count"
            )
        ).all()
        account_rows = db.scalars(
            select(LegacyEndpointTelemetry).where(
                LegacyEndpointTelemetry.counter_name
                == "legacy_account_endpoint_call_count"
            )
        ).all()
        auth_rows = db.scalars(
            select(LegacyEndpointTelemetry).where(
                LegacyEndpointTelemetry.counter_name
                == "legacy_auth_apple_endpoint_call_count"
            )
        ).all()
    finally:
        db.close()

    assert len(backup_rows) >= 4
    assert len(account_rows) >= 1
    assert len(auth_rows) == 1


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
    signal_card_id = capture_response.json()["data"]["recent_signals"][0][
        "signal_card_id"
    ]

    from app.core.db import SessionLocal
    from app.models import (
        CandidateGroup,
        ExperimentCandidate,
        LifeExperimentLifecycleEvent,
        LifeExperimentRollup,
        MicroActionCandidate,
        Observation,
        ObservationSignalLink,
        PipelineRun,
        ReflectionResult,
        TraceLink,
    )

    now = datetime(2026, 7, 13, 10, tzinfo=timezone.utc)
    day = now.date()
    db = SessionLocal()
    try:
        db.add_all(
            [
                CandidateGroup(
                    id="group-delete",
                    user_id="local-user-delete",
                    candidate_kind="micro_action",
                    period_start=day,
                    period_end=day,
                    source_hash="source-delete",
                ),
                MicroActionCandidate(
                    id="micro-delete",
                    candidate_group_id="group-delete",
                    user_id="local-user-delete",
                    local_date=day,
                    rank=1,
                    title="先休息一下",
                    source_hash="source-delete",
                ),
                ExperimentCandidate(
                    id="experiment-candidate-delete",
                    user_id="local-user-delete",
                    source_type="weekly_reflection",
                    source_id="week-delete",
                    source_week_start=day,
                    source_week_end=day,
                    title="减少切换",
                    hypothesis="减少切换可能更省力",
                    suggested_action="每天留一个缓冲",
                ),
                ReflectionResult(
                    id="reflection-delete",
                    user_id="local-user-delete",
                    source_type="weekly_snapshot",
                    source_id="week-delete",
                    reflection_type="reflect",
                    ai_level="L3",
                    content_json={"summary": "待删除"},
                ),
                PipelineRun(
                    id="pipeline-delete",
                    user_id="local-user-delete",
                    pipeline_type="weekly_reflection",
                    source_type="weekly_snapshot",
                    source_id="week-delete",
                    status="success",
                    started_at=now,
                ),
                Observation(
                    id="observation-delete",
                    user_id="local-user-delete",
                    observation_text="待删除的内部假设",
                ),
                TraceLink(
                    id="trace-delete",
                    user_id="local-user-delete",
                    source_type="weekly_snapshot",
                    source_id="week-delete",
                    target_type="signal_card",
                    target_id=signal_card_id,
                    relation_type="uses_trace",
                ),
                LifeExperimentLifecycleEvent(
                    id="lifecycle-delete",
                    experiment_id="life-delete",
                    user_id="local-user-delete",
                    event_type="adopted",
                    event_date=now,
                    local_date=day,
                ),
                LifeExperimentRollup(
                    experiment_id="life-delete",
                    user_id="local-user-delete",
                    root_experiment_id="life-delete",
                    source_week_start=day,
                    source_week_end=day,
                    current_status="active",
                    title="缓冲实验",
                    hypothesis="缓冲有帮助",
                    suggested_action="留十分钟",
                ),
            ]
        )
        db.flush()
        db.add(
            ObservationSignalLink(
                observation_id="observation-delete",
                signal_id=signal_card_id,
            )
        )
        db.commit()
    finally:
        db.close()

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
    for table_name in (
        "candidate_groups",
        "micro_action_candidates",
        "experiment_candidates",
        "reflection_results",
        "pipeline_runs",
        "observations",
        "observation_signal_links",
        "trace_links",
        "life_experiment_lifecycle_events",
        "life_experiment_rollups",
        "signal_processing_state",
        "signal_analysis_policy",
    ):
        assert delete_data["deleted"][table_name] >= 1, table_name

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


def test_backup_restore_cannot_read_another_accounts_bundle(client):
    first_auth = client.post(
        "/api/v1/auth/apple",
        json={"apple_user_id": "apple-backup-owner", "local_user_id": "owner"},
    )
    second_auth = client.post(
        "/api/v1/auth/apple",
        json={"apple_user_id": "apple-backup-other", "local_user_id": "other"},
    )
    assert first_auth.status_code == second_auth.status_code == 200
    owner_headers = {
        "X-Account-Session": first_auth.json()["data"]["session_token"]
    }
    other_headers = {
        "X-Account-Session": second_auth.json()["data"]["session_token"]
    }

    upload = client.post(
        "/api/v1/backup/upload",
        headers=owner_headers,
        json={
            "backup_version": "2026-07-13T00:00:00Z",
            "payload": {"tables": {"signal_cards": []}},
            "counts": {"signal_cards": 0},
        },
    )
    assert upload.status_code == 200, upload.text

    forbidden_restore = client.post(
        "/api/v1/backup/restore-confirmed",
        headers=other_headers,
        json={"backup_id": upload.json()["data"]["id"]},
    )
    assert forbidden_restore.status_code == 404
    assert forbidden_restore.json()["detail"] == "Backup not found"
