from importlib import import_module

from sqlalchemy import func, select


def _headers(user_id: str = "test-user-e2e") -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "X-User-Id": user_id,
    }


def _patch_demo_user(monkeypatch):
    """
    测试里跳过 ensure_demo_user，避免 users/user_profiles 表初始化问题影响
    capture/raw_memory/AI 链路验证。
    """
    def _noop_ensure_demo_user(db, user_id):  # noqa: ANN001
        return None

    targets = [
        ("app.repositories.core_repository", "ensure_demo_user"),
        ("app.repositories.capture_repository", "ensure_demo_user"),
        ("app.services.capture_service", "ensure_demo_user"),
    ]

    for module_name, attr_name in targets:
        try:
            module = import_module(module_name)
            if hasattr(module, attr_name):
                monkeypatch.setattr(module, attr_name, _noop_ensure_demo_user, raising=False)
        except Exception:
            pass


def test_capture_persists_and_recent_returns_acknowledgement(client, monkeypatch):
    _patch_demo_user(monkeypatch)

    resp = client.post(
        "/api/v1/captures",
        headers=_headers(),
        json={
            "content": "今天上班很烦，一直被打断",
            "input_mode": "quick_capture",
            "tag_hint": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    payload = resp.json()
    assert "data" in payload

    data = payload["data"]
    assert isinstance(data.get("acknowledgement"), str)
    assert data["acknowledgement"].strip() != ""

    recent_resp = client.get(
        "/api/v1/captures/recent",
        headers=_headers(),
    )
    assert recent_resp.status_code == 200, recent_resp.text
    recent_payload = recent_resp.json()

    recent_signals = recent_payload["data"]["recent_signals"]
    assert len(recent_signals) >= 1
    assert recent_signals[0]["content"] == "今天上班很烦，一直被打断"
    assert isinstance(recent_signals[0]["acknowledgement"], str)
    assert recent_signals[0]["acknowledgement"].strip() != ""
    assert recent_signals[0]["created_at"].endswith(("Z", "+00:00"))

    from app.core.db import SessionLocal
    from app.models import LegacyEndpointTelemetry

    db = SessionLocal()
    try:
        counters = db.scalars(
            select(LegacyEndpointTelemetry.counter_name).where(
                LegacyEndpointTelemetry.counter_name
                == "legacy_captures_endpoint_call_count"
            )
        ).all()
    finally:
        db.close()
    assert len(counters) >= 2


def test_saved_immediate_risk_signal_uses_safety_reply_and_is_not_analyzable(
    client,
    monkeypatch,
):
    _patch_demo_user(monkeypatch)
    user_id = "saved-safety-signal"
    response = client.post(
        "/api/v1/captures",
        headers=_headers(user_id),
        json={
            "content": "我现在想伤害自己",
            "input_mode": "text",
            "language": "zh-Hans",
            "timezone": "Asia/Tokyo",
        },
    )
    assert response.status_code == 200, response.text
    assert "立即危险" in response.json()["data"]["acknowledgement"]
    signal_id = response.json()["data"]["recent_signals"][0]["signal_card_id"]

    from app.core.db import SessionLocal
    from app.models import SignalAnalysisPolicy, SignalCard, SignalProcessingState
    from app.services.signal_eligibility_service import (
        SignalEligibilityService,
        SignalEligibilityStage,
    )

    db = SessionLocal()
    try:
        signal = db.get(SignalCard, signal_id)
        policy = db.get(SignalAnalysisPolicy, signal_id)
        state = db.get(SignalProcessingState, signal_id)
        assert signal.privacy_level == "sensitive"
        assert signal.metadata_json["safety_branch"] == "immediate_risk"
        assert policy.is_sensitive is True
        assert policy.do_not_analyze is True
        assert policy.exclusion_reason == "immediate_safety_risk"
        assert state.reason_status == "excluded"
        assert state.weekly_status == "excluded"
        assert SignalEligibilityService().is_eligible(
            signal,
            SignalEligibilityStage.WEEKLY,
        ) is False
    finally:
        db.close()


def test_legacy_opportunities_endpoint_records_telemetry(client):
    response = client.get(
        "/api/v1/opportunities",
        headers={
            "X-User-Id": "test-user-opportunities-legacy",
            "X-Client-Version": "4.0.legacy",
            "X-Platform": "ios",
        },
    )
    assert response.status_code == 200, response.text

    from app.core.db import SessionLocal
    from app.models import LegacyEndpointTelemetry

    db = SessionLocal()
    try:
        telemetry = db.scalars(
            select(LegacyEndpointTelemetry).where(
                LegacyEndpointTelemetry.counter_name
                == "legacy_opportunities_endpoint_call_count"
            )
        ).one()
    finally:
        db.close()

    assert telemetry.endpoint == "/api/v1/opportunities"
    assert telemetry.client_version == "4.0.legacy"
    assert telemetry.platform == "ios"
    assert telemetry.user_id_hash is not None


def test_signal_card_soft_delete_and_restore_api(client, monkeypatch):
    _patch_demo_user(monkeypatch)
    headers = _headers("test-user-soft-delete-api")

    create_resp = client.post(
        "/api/v1/captures",
        headers=headers,
        json={
            "content": "会议后很累，需要恢复",
            "input_mode": "quick_capture",
            "client_id": "client-api-soft-delete-1",
        },
    )
    assert create_resp.status_code == 200, create_resp.text
    signal = create_resp.json()["data"]["recent_signals"][0]
    signal_card_id = signal["signal_card_id"]

    delete_resp = client.request(
        "DELETE",
        f"/api/v1/captures/signal-cards/{signal_card_id}",
        headers=headers,
        json={"reason": "user_deleted"},
    )
    assert delete_resp.status_code == 200, delete_resp.text
    deleted = delete_resp.json()["data"]
    assert deleted["status"] == "deleted"
    assert deleted["deleted_at"] is not None
    assert deleted["tombstone_version"] == 1

    recent_after_delete = client.get("/api/v1/captures/recent", headers=headers)
    assert recent_after_delete.status_code == 200
    assert recent_after_delete.json()["data"]["recent_signals"] == []

    replay_resp = client.post(
        "/api/v1/captures",
        headers=headers,
        json={
            "content": "会议后很累，需要恢复",
            "input_mode": "quick_capture",
            "client_id": "client-api-soft-delete-1",
        },
    )
    assert replay_resp.status_code == 200, replay_resp.text
    assert replay_resp.json()["data"]["recent_signals"] == []

    restore_resp = client.post(
        f"/api/v1/captures/signal-cards/{signal_card_id}/restore",
        headers=headers,
        json={},
    )
    assert restore_resp.status_code == 200, restore_resp.text
    restored = restore_resp.json()["data"]
    assert restored["status"] == "restored"
    assert restored["deleted_at"] is None

    recent_after_restore = client.get("/api/v1/captures/recent", headers=headers)
    assert recent_after_restore.status_code == 200
    assert len(recent_after_restore.json()["data"]["recent_signals"]) == 1


def test_capture_api_returns_stable_error_codes(client, monkeypatch):
    _patch_demo_user(monkeypatch)

    missing_user = client.get("/api/v1/captures/recent")
    assert missing_user.status_code == 400
    assert missing_user.json()["detail"]["code"] == "MISSING_USER_ID"
    assert missing_user.json()["detail"]["message"] == "Missing X-User-Id"

    missing_signal = client.request(
        "DELETE",
        "/api/v1/captures/signal-cards/sig_missing_contract",
        headers=_headers("test-user-error-code"),
        json={"reason": "user_deleted"},
    )
    assert missing_signal.status_code == 404
    assert missing_signal.json()["detail"]["code"] == "SIGNAL_CARD_NOT_FOUND"


def test_capture_api_client_id_is_idempotent_and_keeps_source_metadata(
    client,
    monkeypatch,
):
    _patch_demo_user(monkeypatch)
    headers = _headers("test-user-api-idempotent")
    body = {
        "content": "同一个 client_id 重试不应该重复",
        "input_mode": "voice",
        "client_id": "client-api-idempotent-1",
        "raw_payload_json": {
            "audio_uploaded": False,
            "source_kind": "voice_transcript",
        },
    }

    first = client.post("/api/v1/captures", headers=headers, json=body)
    second = client.post("/api/v1/captures", headers=headers, json=body)
    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text

    first_signal = first.json()["data"]["recent_signals"][0]
    second_signal = second.json()["data"]["recent_signals"][0]
    assert first_signal["signal_card_id"] == second_signal["signal_card_id"]
    assert first_signal["client_id"] == "client-api-idempotent-1"
    assert first_signal["source_type"] == "voice"
    assert first_signal["raw_payload_json"]["audio_uploaded"] is False
    assert first_signal["raw_payload_json"]["source_kind"] == "voice_transcript"

    recent = client.get("/api/v1/captures/recent", headers=headers)
    assert recent.status_code == 200, recent.text
    recent_signal = recent.json()["data"]["recent_signals"][0]
    assert recent_signal["source_type"] == "voice"
    assert recent_signal["raw_payload_json"]["audio_uploaded"] is False
    assert recent_signal["raw_payload_json"]["source_kind"] == "voice_transcript"

    from app.core.db import SessionLocal
    from app.models import SignalCard

    db = SessionLocal()
    try:
        count = db.scalar(
            select(func.count()).select_from(SignalCard).where(
                SignalCard.user_id == "test-user-api-idempotent",
                SignalCard.client_id == "client-api-idempotent-1",
            )
        )
        card = db.scalars(
            select(SignalCard).where(
                SignalCard.user_id == "test-user-api-idempotent",
                SignalCard.client_id == "client-api-idempotent-1",
            )
        ).one()
    finally:
        db.close()

    assert count == 1
    assert card.source_type == "voice"
    assert card.raw_payload_json["audio_uploaded"] is False
    assert card.raw_payload_json["source_kind"] == "voice_transcript"


def test_capture_api_preserves_time_use_source_type(client, monkeypatch):
    _patch_demo_user(monkeypatch)
    user_id = "test-user-time-use-source"

    response = client.post(
        "/api/v1/captures",
        headers=_headers(user_id),
        json={
            "content": "上午开会两小时，下午专注写方案。",
            "input_mode": "time_use",
            "language": "zh-Hans",
            "timezone": "Asia/Tokyo",
        },
    )
    assert response.status_code == 200, response.text
    saved = response.json()["data"]["recent_signals"][0]
    assert saved["source_type"] == "time_use"

    recent = client.get(
        "/api/v1/captures/recent",
        headers=_headers(user_id),
    )
    assert recent.status_code == 200, recent.text
    assert recent.json()["data"]["recent_signals"][0]["source_type"] == "time_use"

    from app.core.db import SessionLocal
    from app.models import SignalCard

    db = SessionLocal()
    try:
        card = db.get(SignalCard, saved["signal_card_id"])
        assert card is not None
        assert card.source_type == "time_use"
    finally:
        db.close()


def test_capture_reply_detects_mixed_emotion(client):
    resp = client.post(
        "/api/v1/ai/capture-reply",
        headers=_headers(),
        json={
            "content": "今天上班很烦，但晚上吃到好吃的又缓回来一点",
            "recent_assistant_texts": [],
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert data["emotion"] == "mixed"
    assert isinstance(data["scene_tags"], list)
    assert len(data["scene_tags"]) >= 1


def test_capture_reply_positive_input_not_empty(client):
    resp = client.post(
        "/api/v1/ai/capture-reply",
        headers=_headers(),
        json={
            "content": "今天把拖了很久的东西做完了，心里轻松很多",
            "recent_assistant_texts": [],
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert data["emotion"] in {"positive", "mixed"}
    assert isinstance(data["acknowledgement"], str)
    assert data["acknowledgement"].strip() != ""
    assert isinstance(data["observation"], str)
    assert data["observation"].strip() != ""
    assert isinstance(data["try_next"], str)
    assert data["try_next"].strip() != ""


def test_today_summary_chain_from_saved_capture(client, monkeypatch):
    _patch_demo_user(monkeypatch)

    resp1 = client.post(
        "/api/v1/captures",
        headers=_headers(),
        json={"content": "今天上班很烦", "input_mode": "quick_capture"},
    )
    assert resp1.status_code == 200, resp1.text

    resp2 = client.post(
        "/api/v1/captures",
        headers=_headers(),
        json={"content": "下午又被打断了", "input_mode": "quick_capture"},
    )
    assert resp2.status_code == 200, resp2.text

    recent_resp = client.get("/api/v1/captures/recent", headers=_headers())
    assert recent_resp.status_code == 200, recent_resp.text
    recent_signals = recent_resp.json()["data"]["recent_signals"]

    summary_resp = client.post(
        "/api/v1/ai/today-summary",
        headers=_headers(),
        json={
            "date": "2026-04-14",
            "entry_count": len(recent_signals),
            "entries": recent_signals,
            "focus_area": "emotion_stress",
        },
    )
    assert summary_resp.status_code == 200, summary_resp.text
    data = summary_resp.json()["data"]

    assert isinstance(data["observation"], str)
    assert data["observation"].strip() != ""
    assert isinstance(data["suggestion"], str)
    assert data["suggestion"].strip() != ""


def test_today_summary_still_works_with_v2_entries(client):
    summary_resp = client.post(
        "/api/v1/ai/today-summary",
        headers=_headers(),
        json={
            "date": "2026-04-14",
            "entry_count": 2,
            "entries": [
                {
                    "id": "1",
                    "content": "今天上班很烦",
                    "created_at": "2026-04-14T01:00:00Z",
                    "acknowledgement": "先把这一条放在这里。",
                    "observation": "工作里的打断在磨你。",
                    "try_next": "先记住最卡的那个瞬间。",
                    "emotion": "negative",
                    "intensity": "medium",
                    "scene_tags": ["work"],
                    "intent_tags": ["vent"],
                },
                {
                    "id": "2",
                    "content": "晚上吃到好吃的又缓回来一点",
                    "created_at": "2026-04-14T12:00:00Z",
                    "acknowledgement": "后面有一点被接住了。",
                    "observation": "具体的小好事会把你拉回来。",
                    "try_next": "记住什么让你缓回来。",
                    "emotion": "positive",
                    "intensity": "low",
                    "scene_tags": ["daily_life"],
                    "intent_tags": ["celebrate"],
                },
            ],
            "focus_area": "emotion_stress",
        },
    )
    assert summary_resp.status_code == 200, summary_resp.text
    data = summary_resp.json()["data"]

    assert isinstance(data["observation"], str)
    assert data["observation"].strip() != ""
    assert isinstance(data["suggestion"], str)
    assert data["suggestion"].strip() != ""


def test_weekly_generate_chain_with_local_style_payload(client):
    payload = {
        "week_start": "2026-04-08",
        "week_end": "2026-04-14",
        "entry_count": 3,
        "entries": [
            {
                "id": "1",
                "content": "今天上班很烦",
                "created_at": "2026-04-12T01:00:00Z",
                "acknowledgement": "先把这一条放在这里。",
            },
            {
                "id": "2",
                "content": "下午又被打断",
                "created_at": "2026-04-13T01:00:00Z",
                "acknowledgement": "这种一直被切断的感觉很消耗。",
            },
            {
                "id": "3",
                "content": "今天还是烦",
                "created_at": "2026-04-14T01:00:00Z",
                "acknowledgement": "重复本身就很磨人。",
            },
        ],
        "day_counts": {
            "2026-04-12": 1,
            "2026-04-13": 1,
            "2026-04-14": 1,
        },
        "top_tokens": ["烦", "打断"],
        "focus_area": "emotion_stress",
    }

    resp = client.post(
        "/api/v1/ai/weekly-generate",
        headers=_headers(),
        json=payload,
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert data["status"] == "ready"
    assert isinstance(data["key_insight"], str)
    assert data["key_insight"].strip() != ""
    assert isinstance(data["patterns"], list)
    assert len(data["patterns"]) > 0
    assert isinstance(data["frictions"], list)
    assert len(data["frictions"]) > 0
    assert isinstance(data["best_action"], str)
    assert data["best_action"].strip() != ""


def test_journey_generate_chain_with_local_style_payload(client):
    payload = {
        "snapshot_date": "2026-04-14",
        "entry_count": 3,
        "entries": [
            {
                "id": "1",
                "content": "前天上班很烦",
                "created_at": "2026-04-12T01:00:00Z",
                "acknowledgement": "先把这一条放在这里。",
            },
            {
                "id": "2",
                "content": "昨天还是烦",
                "created_at": "2026-04-13T01:00:00Z",
                "acknowledgement": "这类感觉已经不是第一次了。",
            },
            {
                "id": "3",
                "content": "今天又被打断",
                "created_at": "2026-04-14T01:00:00Z",
                "acknowledgement": "节奏被切断真的很耗人。",
            },
        ],
        "top_tokens": ["烦", "打断"],
        "total_days": 3,
        "focus_area": "emotion_stress",
    }

    resp = client.post(
        "/api/v1/ai/journey-generate",
        headers=_headers(),
        json=payload,
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert isinstance(data["patterns"], list) and len(data["patterns"]) > 0
    assert isinstance(data["frictions"], list) and len(data["frictions"]) > 0
    assert isinstance(data["desires"], list) and len(data["desires"]) > 0
    assert isinstance(data["experiments"], list) and len(data["experiments"]) > 0


def test_today_summary_chain_respects_response_style(client):
    summary_resp = client.post(
        "/api/v1/ai/today-summary",
        headers=_headers(),
        json={
            "date": "2026-04-14",
            "entry_count": 2,
            "entries": [
                {"id": "1", "content": "今天上班很烦", "created_at": "2026-04-14T01:00:00Z"},
                {"id": "2", "content": "下午又被打断", "created_at": "2026-04-14T12:00:00Z"},
            ],
            "focus_area": "emotion_stress",
            "response_style": "direct",
        },
    )
    assert summary_resp.status_code == 200, summary_resp.text
    data = summary_resp.json()["data"]
    assert data["observation"].startswith("重点是：")
    assert data["suggestion"].startswith("下一步：")
