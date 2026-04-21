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


def test_light_dialog_contract(client):
    resp = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers(),
        json={
            "capture_content": "今天上班很烦，一直被打断",
            "capture_acknowledgement": "先把这条放在这里。",
            "capture_observation": "工作里的打断在磨你。",
            "capture_try_next": "先记住最卡的瞬间。",
            "history": [
                {"role": "assistant", "text": "先把这条放在这里。"},
                {"role": "user", "text": "为什么我会这么烦？"},
            ],
            "user_message": "为什么我会这么烦？",
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]
    assert set(data.keys()) >= {"reply", "suggested_prompts"}
    assert isinstance(data["reply"], str)
    assert data["reply"].strip() != ""
    assert isinstance(data["suggested_prompts"], list)


def test_deep_weekly_contract(client):
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
    assert set(data.keys()) >= {
        "summary",
        "root_tension",
        "hidden_pattern",
        "next_focus",
        "risk_note",
        "key_nodes",
    }
