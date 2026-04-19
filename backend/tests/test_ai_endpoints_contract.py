def _headers(user_id: str = "test-user-contract") -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "X-User-Id": user_id,
    }


def test_capture_reply_contract(client):
    resp = client.post(
        "/api/v1/ai/capture-reply",
        headers=_headers(),
        json={
            "content": "今天上班很烦",
            "recent_assistant_texts": [],
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    expected_keys = {
        "acknowledgement",
        "observation",
        "try_next",
        "emotion",
        "intensity",
        "scene_tags",
        "intent_tags",
        "followup",
    }
    assert expected_keys.issubset(data.keys())

    assert isinstance(data["acknowledgement"], str)
    assert data["acknowledgement"].strip() != ""
    assert isinstance(data["observation"], str)
    assert data["observation"].strip() != ""
    assert isinstance(data["try_next"], str)
    assert data["try_next"].strip() != ""
    assert data["emotion"] in {"positive", "negative", "mixed", "neutral"}
    assert data["intensity"] in {"low", "medium", "high"}
    assert isinstance(data["scene_tags"], list)
    assert isinstance(data["intent_tags"], list)


def test_today_summary_contract(client):
    resp = client.post(
        "/api/v1/ai/today-summary",
        headers=_headers(),
        json={
            "date": "2026-04-14",
            "entry_count": 1,
            "entries": [
                {
                    "id": "1",
                    "content": "今天上班很烦",
                    "created_at": "2026-04-14T01:00:00Z",
                    "acknowledgement": "先放在这里。",
                    "observation": "今天更明显的是工作场景在消耗你。",
                    "try_next": "先记住最卡的那个瞬间。",
                    "emotion": "negative",
                    "intensity": "medium",
                    "scene_tags": ["work"],
                    "intent_tags": ["vent"],
                }
            ],
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert set(data.keys()) >= {"observation", "suggestion"}
    assert isinstance(data["observation"], str)
    assert data["observation"].strip() != ""
    assert isinstance(data["suggestion"], str)
    assert data["suggestion"].strip() != ""


def test_weekly_generate_contract(client):
    resp = client.post(
        "/api/v1/ai/weekly-generate",
        headers=_headers(),
        json={
            "week_start": "2026-04-08",
            "week_end": "2026-04-14",
            "entry_count": 1,
            "entries": [
                {
                    "id": "1",
                    "content": "今天上班很烦",
                    "created_at": "2026-04-14T01:00:00Z",
                    "acknowledgement": "先放在这里。",
                }
            ],
            "day_counts": {"2026-04-14": 1},
            "top_tokens": ["烦"],
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    expected_keys = {
        "week_start",
        "week_end",
        "status",
        "key_insight",
        "patterns",
        "frictions",
        "best_action",
        "opportunity_snapshot",
        "feedback_submitted",
    }
    assert expected_keys.issubset(data.keys())


def test_journey_generate_contract(client):
    resp = client.post(
        "/api/v1/ai/journey-generate",
        headers=_headers(),
        json={
            "snapshot_date": "2026-04-14",
            "entry_count": 1,
            "entries": [
                {
                    "id": "1",
                    "content": "今天上班很烦",
                    "created_at": "2026-04-14T01:00:00Z",
                    "acknowledgement": "先放在这里。",
                }
            ],
            "top_tokens": ["烦"],
            "total_days": 1,
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    expected_keys = {"patterns", "frictions", "desires", "experiments"}
    assert expected_keys.issubset(data.keys())
