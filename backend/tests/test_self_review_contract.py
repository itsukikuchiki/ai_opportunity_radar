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


def test_self_review_generated_copy_uses_requested_language(client):
    cases = [
        ("zh-Hant", "今天工作一直被打斷", "工作", "反覆"),
        ("ja", "今日は仕事で何度も中断された", "仕事", "繰り返し"),
        ("en", "Work was interrupted repeatedly today", "work", "recurring"),
    ]
    for index, (language, content, scene, expected) in enumerate(cases):
        response = client.post(
            "/api/v1/ai/self-review",
            headers=_headers(f"self-review-language-{index}"),
            json={
                "entry_count": 1,
                "entries": [
                    {
                        "id": "1",
                        "content": content,
                        "emotion": "negative",
                        "scene_tags": [scene],
                    }
                ],
                "top_tokens": [content],
                "total_days": 1,
                "language": language,
            },
        )
        assert response.status_code == 200, response.text
        data = response.json()["data"]
        generated = " ".join([
            *data["repeated_blockers"],
            *data["main_drains"],
            *data["helping_patterns"],
            data["closing_note"],
        ])
        assert expected in generated
