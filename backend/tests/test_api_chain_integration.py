from importlib import import_module


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


def test_capture_reply_returns_observation_and_try_next(client):
    resp = client.post(
        "/api/v1/ai/capture-reply",
        headers=_headers(),
        json={
            "content": "今天上班很烦，一直被打断",
            "recent_assistant_texts": [],
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert isinstance(data["acknowledgement"], str)
    assert data["acknowledgement"].strip() != ""
    assert isinstance(data["observation"], str)
    assert data["observation"].strip() != ""
    assert isinstance(data["try_next"], str)
    assert data["try_next"].strip() != ""
    assert data["emotion"] in {"positive", "negative", "mixed", "neutral"}
    assert data["intensity"] in {"low", "medium", "high"}


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


def test_light_dialog_chain(client):
    resp = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers(),
        json={
            "capture_content": "今天上班很烦，一直被打断",
            "capture_acknowledgement": "先把这条放在这里。",
            "history": [{"role": "assistant", "text": "先把这条放在这里。"}],
            "user_message": "那我到底为什么这么烦？",
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]
    assert isinstance(data["reply"], str)
    assert data["reply"].strip() != ""
    assert isinstance(data["suggested_prompts"], list)


def test_deep_weekly_chain(client):
    resp = client.post(
        "/api/v1/ai/deep-weekly",
        headers=_headers(),
        json={
            "week_start": "2026-04-08",
            "week_end": "2026-04-14",
            "key_insight": "这周的记录开始围绕工作里的打断聚集。",
            "patterns": [{"name": "重复出现的主题", "summary": "工作里的打断反复回来。"}],
            "frictions": [{"name": "本周的主要消耗", "summary": "被打断时最容易烦躁。"}],
            "best_action": "下次再出现时补一句发生在什么场景。",
            "chart_data": [{"date": "2026-04-11", "signal_count": 3, "mood_score": -0.6, "friction_score": 0.8, "has_positive_signal": False}],
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]
    assert data["summary"].strip() != ""
    assert data["root_tension"].strip() != ""
    assert isinstance(data["key_nodes"], list)
