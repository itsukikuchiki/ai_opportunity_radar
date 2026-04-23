def _headers(user_id: str = "test-user-self-review-e2e") -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "X-User-Id": user_id,
    }


def test_self_review_chain_ready(client):
    resp = client.post(
        "/api/v1/ai/self-review",
        headers=_headers(),
        json={
            "entry_count": 3,
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
                {
                    "id": "3",
                    "content": "晚上散步之后会稍微缓回来一些",
                    "created_at": "2026-04-22T01:00:00Z",
                    "acknowledgement": "后面有一点被接住了。",
                    "emotion": "positive",
                    "intensity": "low",
                    "scene_tags": ["rest"],
                    "intent_tags": ["record"],
                },
            ],
            "top_tokens": ["打断", "散步"],
            "total_days": 3,
            "focus_area": "work_tasks",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert data["status"] == "ready"
    assert len(data["repeated_blockers"]) > 0
    assert len(data["main_drains"]) > 0
    assert len(data["helping_patterns"]) > 0
    assert data["closing_note"].strip() != ""
