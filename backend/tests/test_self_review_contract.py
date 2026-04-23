def _headers(user_id: str = "test-user-self-review") -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "X-User-Id": user_id,
    }


def test_self_review_contract(client):
    resp = client.post(
        "/api/v1/ai/self-review",
        headers=_headers(),
        json={
            "entry_count": 2,
            "entries": [
                {
                    "id": "1",
                    "content": "今天开会一直被打断",
                    "created_at": "2026-04-20T01:00:00Z",
                    "acknowledgement": "先把这条放在这里。",
                    "emotion": "negative",
                    "intensity": "medium",
                    "scene_tags": ["work"],
                    "intent_tags": ["vent"],
                },
                {
                    "id": "2",
                    "content": "下午又被同类事情打断了",
                    "created_at": "2026-04-21T01:00:00Z",
                    "acknowledgement": "重复本身就很磨人。",
                    "emotion": "negative",
                    "intensity": "medium",
                    "scene_tags": ["work"],
                    "intent_tags": ["vent"],
                },
            ],
            "top_tokens": ["打断", "开会"],
            "total_days": 2,
            "focus_area": "work_tasks",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert set(data.keys()) >= {
        "status",
        "reviewed_days",
        "repeated_blockers",
        "main_drains",
        "helping_patterns",
        "closing_note",
    }
    assert data["status"] in {"ready", "insufficient_data"}
    assert isinstance(data["repeated_blockers"], list)
    assert isinstance(data["main_drains"], list)
    assert isinstance(data["helping_patterns"], list)
    assert isinstance(data["closing_note"], str)
