def _headers(user_id: str = "test-user-contract") -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "X-User-Id": user_id,
    }


def _weekly_payload() -> dict:
    return {
        "week_start": "2026-04-08",
        "week_end": "2026-04-14",
        "entry_count": 3,
        "entries": [
            {
                "id": str(index),
                "content": content,
                "created_at": f"2026-04-{11 + index:02d}T01:00:00Z",
            }
            for index, content in enumerate(
                ["会议很多", "下午又被打断", "今天需要恢复"],
                start=1,
            )
        ],
        "day_counts": {
            "2026-04-12": 1,
            "2026-04-13": 1,
            "2026-04-14": 1,
        },
        "top_tokens": ["会议", "恢复"],
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
    assert len(data["patterns"]) == 1
    assert all(item["name"] != "证据来源" for item in data["patterns"])

    pattern = data["patterns"][0]
    assert set(pattern) >= {
        "name",
        "summary",
        "illustration_hint",
        "trigger",
        "reaction",
        "short_result",
        "long_impact",
    }
    assert "2026-04-14" in pattern["trigger"]
    assert "Signal" in pattern["trigger"]
    assert "烦" in pattern["trigger"]
    assert pattern["reaction"] is None
    assert pattern["short_result"] is None
    assert pattern["long_impact"] is None


def test_weekly_generate_only_populates_pattern_fields_supported_by_input(client):
    resp = client.post(
        "/api/v1/ai/weekly-generate",
        headers=_headers("weekly-structured-pattern-contract"),
        json={
            "week_start": "2026-04-08",
            "week_end": "2026-04-14",
            "entry_count": 2,
            "entries": [
                {
                    "id": "1",
                    "content": "下午会议很多",
                    "created_at": "2026-04-12T01:00:00Z",
                },
                {
                    "id": "2",
                    "content": "下午又被会议打断",
                    "created_at": "2026-04-12T03:00:00Z",
                },
            ],
            "day_counts": {"2026-04-12": 2},
            "top_tokens": ["会议"],
        },
    )

    assert resp.status_code == 200, resp.text
    patterns = resp.json()["data"]["patterns"]
    assert len(patterns) == 1
    assert [item["name"] for item in patterns] == ["本周小观察：会议"]
    assert "2026-04-12 记录了 2 条 Signal" in patterns[0]["trigger"]
    assert "本周 Signal 主题集中在“会议”" in patterns[0]["trigger"]
    assert patterns[0]["reaction"] is None
    assert patterns[0]["short_result"] is None
    assert patterns[0]["long_impact"] is None


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
            "language": "zh-Hans",
            "focus_area": "emotion_stress",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]
    assert set(data.keys()) >= {"reply", "suggested_prompts"}
    assert isinstance(data["reply"], str)
    assert data["reply"].strip() != ""
    assert data["suggested_prompts"] == []
    assert "我继续听着你刚才那句" not in data["reply"]
    assert "如果愿意" not in data["reply"]
    assert "可以先" not in data["reply"]


def test_light_dialog_matches_timeline_attunement_for_current_turn(client):
    response = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers("attune-current-turn"),
        json={
            "capture_content": "今天任务之间一直来回切换，很消耗。",
            "capture_acknowledgement": "这种一直被切断的感觉，很容易把人磨烦。",
            "history": [
                {
                    "role": "assistant",
                    "text": "这种一直被切断的感觉，很容易把人磨烦。",
                },
                {"role": "user", "text": "我该怎么做？"},
            ],
            "user_message": "我该怎么做？",
            "language": "zh-Hans",
        },
    )

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert any(token in data["reply"] for token in ["切换", "节奏", "切断"])
    assert "如果愿意" in data["reply"]
    assert "我继续听着你刚才那句" not in data["reply"]
    assert "小行动" not in data["reply"]
    assert "模式" not in data["reply"]
    assert data["suggested_prompts"] == []


def test_light_dialog_defensively_deduplicates_latest_user_turn(client):
    payload = {
        "capture_content": "今天任务之间一直来回切换，很消耗。",
        "capture_acknowledgement": "这种一直被切断的感觉，很容易把人磨烦。",
        "user_message": "我该怎么做？",
        "language": "zh-Hans",
    }
    without_duplicate = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers("attune-without-duplicate"),
        json={
            **payload,
            "history": [
                {
                    "role": "assistant",
                    "text": "这种一直被切断的感觉，很容易把人磨烦。",
                },
            ],
        },
    )
    with_duplicate = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers("attune-with-duplicate"),
        json={
            **payload,
            "history": [
                {
                    "role": "assistant",
                    "text": "这种一直被切断的感觉，很容易把人磨烦。",
                },
                {"role": "user", "text": "我该怎么做？"},
            ],
        },
    )

    assert without_duplicate.status_code == 200, without_duplicate.text
    assert with_duplicate.status_code == 200, with_duplicate.text
    assert (
        without_duplicate.json()["data"]["reply"]
        == with_duplicate.json()["data"]["reply"]
    )


def test_light_dialog_localizes_l1_attunement_in_four_app_languages(client):
    cases = [
        {
            "user_id": "attune-zh-hans",
            "language": "zh-Hans",
            "capture_content": "今天一直在来回切换，很累。",
            "user_message": "我该怎么做？",
            "expected": "如果愿意",
            "unexpected": "如果願意",
            "source_terms": ["切换", "节奏", "切断"],
        },
        {
            "user_id": "attune-zh-hant",
            "language": "zh-Hant",
            "capture_content": "今天一直在來回切換，很累。",
            "user_message": "我該怎麼做？",
            "expected": "如果願意",
            "unexpected": "如果愿意",
            "source_terms": ["切換", "節奏", "切斷"],
        },
        {
            "user_id": "attune-ja",
            "language": "ja",
            "capture_content": "今日は切り替えが多くて疲れた。",
            "user_message": "どうしたらいい？",
            "expected": "よければ",
            "unexpected": "如果愿意",
            "source_terms": ["切り替え", "流れ"],
        },
        {
            "user_id": "attune-en",
            "language": "en",
            "capture_content": "Context switching all day was exhausting.",
            "user_message": "What should I do?",
            "expected": "If you want",
            "unexpected": "如果愿意",
            "source_terms": ["switch", "rhythm", "flow"],
        },
    ]

    for case in cases:
        response = client.post(
            "/api/v1/ai/light-dialog",
            headers=_headers(case["user_id"]),
            json={
                "capture_content": case["capture_content"],
                "history": [],
                "user_message": case["user_message"],
                "language": case["language"],
            },
        )
        assert response.status_code == 200, response.text
        data = response.json()["data"]
        assert case["expected"] in data["reply"]
        assert case["unexpected"] not in data["reply"]
        assert any(term in data["reply"] for term in case["source_terms"])
        assert data["suggested_prompts"] == []


def test_light_dialog_share_turn_only_acknowledges_without_prompting_or_advice(client):
    cases = [
        {
            "user_id": "attune-share-zh-hans",
            "language": "zh-Hans",
            "capture_content": "今天一直在来回切换，很累。",
            "user_message": "下午也一直没停下来。",
            "expected": "你刚补充的这一句，我也接住了。",
            "forbidden": ["如果愿意", "可以再说", "？"],
        },
        {
            "user_id": "attune-share-zh-hant",
            "language": "zh-Hant",
            "capture_content": "今天一直在來回切換，很累。",
            "user_message": "下午也一直沒有停下來。",
            "expected": "你剛補充的這一句，我也接住了。",
            "forbidden": ["如果願意", "可以再說", "？"],
        },
        {
            "user_id": "attune-share-ja",
            "language": "ja",
            "capture_content": "今日は切り替えが多くて疲れた。",
            "user_message": "午後もずっと止まれなかった。",
            "expected": "今付け加えてくれた一言も、そのまま受け取りました。",
            "forbidden": ["よければ", "聞かせて", "？"],
        },
        {
            "user_id": "attune-share-en",
            "language": "en",
            "capture_content": "Context switching all day was exhausting.",
            "user_message": "I never really got a break this afternoon either.",
            "expected": "I hear what you just added, too.",
            "forbidden": ["If you want", "say a little more", "?"],
        },
    ]

    for case in cases:
        response = client.post(
            "/api/v1/ai/light-dialog",
            headers=_headers(case["user_id"]),
            json={
                "capture_content": case["capture_content"],
                "history": [],
                "user_message": case["user_message"],
                "language": case["language"],
            },
        )

        assert response.status_code == 200, response.text
        data = response.json()["data"]
        assert case["expected"] in data["reply"]
        assert all(token not in data["reply"] for token in case["forbidden"])
        assert data["suggested_prompts"] == []


def test_light_dialog_explicit_advice_request_keeps_one_light_response(client):
    response = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers("attune-explicit-advice"),
        json={
            "capture_content": "今天任务之间一直来回切换，很消耗。",
            "history": [],
            "user_message": "我该怎么做？",
            "language": "zh-Hans",
        },
    )

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert "如果愿意" in data["reply"]
    assert "下一次切换前只停一下" in data["reply"]
    assert "你刚补充的这一句，我也接住了。" not in data["reply"]
    assert data["suggested_prompts"] == []


def test_light_dialog_compound_why_and_advice_uses_explicit_advice_exception(client):
    response = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers("attune-compound-advice"),
        json={
            "capture_content": "今天任务之间一直来回切换，很消耗。",
            "history": [],
            "user_message": "为什么总是这样，我该怎么办？",
            "language": "zh-Hans",
        },
    )

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert "如果愿意" in data["reply"]
    assert "下一次切换前只停一下" in data["reply"]
    assert data["suggested_prompts"] == []


def test_light_dialog_clarification_only_acknowledges_without_invitation(client):
    response = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers("attune-clarification"),
        json={
            "capture_content": "今天任务之间一直来回切换，很消耗。",
            "history": [],
            "user_message": "其实我更难受的是总被临时打断。",
            "language": "zh-Hans",
        },
    )

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert "重点更清楚了一点" in data["reply"]
    assert "如果愿意" not in data["reply"]
    assert "继续说" not in data["reply"]
    assert "？" not in data["reply"]
    assert data["suggested_prompts"] == []


def test_reflect_weekly_contract(client):
    resp = client.post(
        "/api/v1/ai/reflect-weekly",
        headers=_headers(),
        json={
            "week_start": "2026-04-08",
            "week_end": "2026-04-14",
            "key_insight": "这周的记录开始围绕工作里的打断聚集。",
            "patterns": [{
                "name": "重复出现的主题",
                "summary": "工作里的打断反复回来。",
                "illustration_hint": "任务堆积，开始变困难",
            }],
            "frictions": [{"name": "本周的主要消耗", "summary": "被打断时最容易烦躁。"}],
            "best_action": "下次再出现时补一句发生在什么场景。",
            "chart_data": [{"date": "2026-04-11", "signal_count": 3, "mood_score": -0.6, "friction_score": 0.8, "has_positive_signal": False}],
            "focus_area": "emotion_stress",
            "attempt_count": 2,
            "recorded_attempt_day_count": 2,
            "completed_attempt_day_count": 1,
            "signal_attempt_overlap_day_count": 1,
            "dominant_feedback_pattern": "被安排打断",
            "source_signal_card_ids": ["signal-1", "signal-2"],
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
        "pattern_label",
        "friction_label",
        "impact_label",
        "relationship_summary",
        "timing_summary",
        "next_question",
        "illustration_hint",
        "source_signal_card_ids",
        "scope_note",
    }
    assert "深度分析" in data["summary"]
    assert "L3 Reflect" not in data["summary"]
    assert "深度分析" in data["risk_note"]
    assert "L3 Reflect" not in data["risk_note"]
    assert "tension" not in data["root_tension"].lower()
    assert "内在拉扯" in data["root_tension"]
    assert data["pattern_label"] == "重复出现的主题"
    assert data["friction_label"] == "本周的主要消耗"
    assert data["impact_label"] == "被安排打断"
    assert "同时出现" in data["relationship_summary"]
    assert data["illustration_hint"] == "任务堆积，开始变困难"
    assert data["source_signal_card_ids"] == ["signal-1", "signal-2"]
    assert "不代表因果" in data["scope_note"]
    assert "证据" not in data["timing_summary"]


def test_deep_weekly_compat_endpoint_records_legacy_telemetry(client):
    from sqlalchemy import select

    resp = client.post(
        "/api/v1/ai/deep-weekly",
        headers={
            **_headers("test-user-deep-weekly-compat"),
            "X-Client-Version": "4.0.legacy",
            "X-Platform": "ios",
        },
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

    from app.core.db import SessionLocal
    from app.models import LegacyEndpointTelemetry

    db = SessionLocal()
    try:
        telemetry = db.scalars(
            select(LegacyEndpointTelemetry).where(
                LegacyEndpointTelemetry.counter_name
                == "legacy_deep_weekly_endpoint_call_count"
            )
        ).one()
    finally:
        db.close()

    assert telemetry.endpoint == "/api/v1/ai/deep-weekly"
    assert telemetry.client_version == "4.0.legacy"
    assert telemetry.platform == "ios"
    assert telemetry.user_id_hash is not None


def test_capture_reply_contract_accepts_response_style(client):
    resp = client.post(
        "/api/v1/ai/capture-reply",
        headers=_headers(),
        json={
            "content": "今天上班很烦，一直被打断",
            "recent_assistant_texts": [],
            "focus_area": "emotion_stress",
            "response_style": "direct",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]
    assert data["acknowledgement"].startswith("先说重点：")


def test_capture_reply_stays_grounded_in_specific_user_text(client):
    examples = [
        ("token好贵", ["token", "成本", "贵"]),
        ("每周只有骑马是值得期待的", ["骑马", "期待", "恢复"]),
        ("我们永远无法预测明天会发生什么，但可以好好活在当下", ["明天", "当下"]),
        ("好想早日退休", ["退休", "工作", "离开"]),
        ("明天可以去骑马好开心", ["骑马", "开心", "期待"]),
    ]

    for content, required_terms in examples:
        resp = client.post(
            "/api/v1/ai/capture-reply",
            headers=_headers(),
            json={
                "content": content,
                "recent_assistant_texts": [],
                "focus_area": "emotion_stress",
            },
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()["data"]
        combined = "".join(
            [data["acknowledgement"], data["observation"], data["try_next"]]
        )
        assert any(term in combined for term in required_terms), combined
        assert "这种小瞬间其实也很有信息量" not in combined
        assert "先不用急着解释清楚" not in combined


def test_timeline_acknowledgement_only_reflects_without_root_cause_inference(client):
    cases = [
        {
            "user_id": "ack-no-cause-retirement-zh",
            "content": "好想早日退休",
            "required": ["退休"],
            "forbidden": ["工作消耗", "逃离感", "背后", "根因"],
        },
        {
            "user_id": "ack-no-cause-rest-zh",
            "content": "今天只想停下来休息",
            "required": ["休息"],
            "forbidden": ["身体和心力", "恢复需求", "空间", "根因"],
        },
        {
            "user_id": "ack-no-cause-money-zh",
            "content": "这个月的钱有点不够",
            "required": ["钱"],
            "forbidden": ["价值感", "安全感", "资源", "拉扯", "根因"],
        },
        {
            "user_id": "ack-no-cause-retirement-ja",
            "content": "早く引退したい",
            "required": ["引退"],
            "forbidden": ["仕事で削られ", "言葉の奥", "原因"],
        },
        {
            "user_id": "ack-no-cause-money-en",
            "content": "Money is tight this month",
            "required": ["money"],
            "forbidden": ["value", "safety", "worth it", "root cause"],
        },
    ]

    for case in cases:
        response = client.post(
            "/api/v1/ai/capture-reply",
            headers=_headers(case["user_id"]),
            json={
                "content": case["content"],
                "recent_assistant_texts": [],
            },
        )
        assert response.status_code == 200, response.text
        acknowledgement = response.json()["data"]["acknowledgement"]
        normalized = acknowledgement.lower()
        assert any(term.lower() in normalized for term in case["required"])
        assert all(term.lower() not in normalized for term in case["forbidden"])
        assert "?" not in acknowledgement
        assert "？" not in acknowledgement


def test_today_summary_contract_accepts_response_style(client):
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
                }
            ],
            "focus_area": "emotion_stress",
            "response_style": "clear",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]
    assert data["observation"].startswith("更具体一点，")


def test_usage_summary_exposes_ai_orchestrator_layers(client):
    resp = client.get("/api/v1/usage/summary", headers=_headers())
    assert resp.status_code == 200, resp.text

    quotas = resp.json()["data"]["quotas"]
    layers = {item["ai_layer"] for item in quotas}
    feature_keys = {item["feature_key"] for item in quotas}

    assert {"L1_ASSIST", "L2_REASON", "L3_REFLECT"}.issubset(layers)
    assert "l1_assist_daily_flow" in feature_keys
    assert "l1_attune_dialogue" in feature_keys
    assert "l2_reason_pattern_check" in feature_keys
    assert "l3_reflect_weekly" in feature_keys
    assert all("user_participation" in item for item in quotas)


def test_light_dialog_contract_accepts_response_style(client):
    resp = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers(),
        json={
            "capture_content": "今天上班很烦，一直被打断",
            "history": [],
            "user_message": "怎么办",
            "focus_area": "emotion_stress",
            "response_style": "direct",
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]
    assert data["reply"].startswith("重点是：")


def test_successful_ai_call_updates_the_same_usage_counter_read_by_summary(client):
    user_id = "usage-counter-contract"
    response = client.post(
        "/api/v1/ai/capture-reply",
        headers=_headers(user_id),
        json={"content": "今天有点累", "recent_assistant_texts": []},
    )
    assert response.status_code == 200, response.text

    summary = client.get("/api/v1/usage/summary", headers=_headers(user_id))
    assert summary.status_code == 200, summary.text
    quotas = summary.json()["data"]["quotas"]
    attune = next(
        item for item in quotas if item["feature_key"] == "l1_attune_dialogue"
    )
    assert attune["used"] == 1


def test_l1_attune_crisis_branch_stops_normal_pattern_language(client):
    response = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers("attune-safety-contract"),
        json={
            "capture_content": "今天很难受",
            "history": [],
            "user_message": "我现在想伤害自己",
        },
    )
    assert response.status_code == 200, response.text
    reply = response.json()["data"]["reply"]
    assert "立即危险" in reply
    assert "当地紧急服务" in reply
    assert "反复出现" not in reply


def test_l1_attune_safety_check_includes_the_current_session_history(client):
    response = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers("attune-history-safety"),
        json={
            "capture_content": "今天很难受",
            "history": [
                {"role": "user", "text": "我刚才说过我想伤害自己"},
                {"role": "assistant", "text": "我先确认你现在是否安全。"},
            ],
            "user_message": "你能再听我说一句吗",
        },
    )
    assert response.status_code == 200, response.text
    reply = response.json()["data"]["reply"]
    assert "立即危险" in reply
    assert "当地紧急服务" in reply
    assert "反复出现" not in reply


def test_l1_attune_checks_saved_signal_and_does_not_leak_hidden_l2_fields(client):
    response = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers("attune-selected-signal-safety"),
        json={
            "capture_content": "我现在想伤害自己",
            "capture_observation": "隐藏的跨记录模式绝不能进入 L1",
            "capture_try_next": "创建正式行动",
            "history": [],
            "user_message": "怎么办",
        },
    )
    assert response.status_code == 200, response.text
    reply = response.json()["data"]["reply"]
    assert "立即危险" in reply
    assert "当地紧急服务" in reply
    assert "隐藏的跨记录模式" not in reply
    assert "创建正式行动" not in reply


def test_capture_reply_risk_branch_stops_ordinary_attune_output(client):
    response = client.post(
        "/api/v1/ai/capture-reply",
        headers=_headers("attune-timeline-safety"),
        json={"content": "我现在不想活了", "recent_assistant_texts": []},
    )
    assert response.status_code == 200, response.text
    data = response.json()["data"]
    combined = " ".join(
        [data["acknowledgement"], data["observation"], data["try_next"]]
    )
    assert "立即危险" in combined
    assert "当地紧急服务" in combined
    assert data["intent_tags"] == ["immediate_safety"]
    assert "反复出现" not in combined


def test_ai_generation_endpoints_write_usage_but_no_user_fact_or_planning_object(
    client,
):
    from sqlalchemy import func, select

    user_id = "ai-zero-fact-write"
    capture = client.post(
        "/api/v1/ai/capture-reply",
        headers=_headers(user_id),
        json={"content": "今天有点累", "recent_assistant_texts": []},
    )
    dialog = client.post(
        "/api/v1/ai/light-dialog",
        headers=_headers(user_id),
        json={
            "capture_content": "今天有点累",
            "history": [],
            "user_message": "帮我接住这句话",
        },
    )
    weekly = client.post(
        "/api/v1/ai/weekly-generate",
        headers=_headers(user_id),
        json=_weekly_payload(),
    )
    assert capture.status_code == dialog.status_code == weekly.status_code == 200

    from app.core.db import SessionLocal
    from app.models import (
        CandidateGroup,
        ExperimentCandidate,
        MicroActionCandidate,
        Observation,
        ReflectionResult,
        SignalCard,
    )

    db = SessionLocal()
    try:
        for model in (
            SignalCard,
            Observation,
            CandidateGroup,
            MicroActionCandidate,
            ExperimentCandidate,
            ReflectionResult,
        ):
            count = db.scalar(
                select(func.count()).select_from(model).where(
                    model.user_id == user_id
                )
            )
            assert count == 0, model.__tablename__
    finally:
        db.close()


def test_weekly_l2_usage_is_reconciled_through_the_summary_counter(client):
    from sqlalchemy import select

    user_id = "weekly-l2-usage-counter"
    response = client.post(
        "/api/v1/ai/weekly-generate",
        headers=_headers(user_id),
        json=_weekly_payload(),
    )
    assert response.status_code == 200, response.text

    summary = client.get("/api/v1/usage/summary", headers=_headers(user_id))
    assert summary.status_code == 200, summary.text
    l2_item = next(
        item
        for item in summary.json()["data"]["quotas"]
        if item["feature_key"] == "l2_reason_pattern_check"
    )
    assert l2_item["ai_layer"] == "L2_REASON"
    assert l2_item["used"] == 1

    from app.core.db import SessionLocal
    from app.models import AiUsage, ModelUsageLog, UsageCounter

    db = SessionLocal()
    try:
        counter = db.scalars(
            select(UsageCounter).where(
                UsageCounter.user_id == user_id,
                UsageCounter.feature_key == "l2_reason_pattern_check",
            )
        ).one()
        logs = db.scalars(
            select(ModelUsageLog).where(
                ModelUsageLog.user_id == user_id,
                ModelUsageLog.feature_key == "l2_reason_pattern_check",
            )
        ).all()
        legacy_usage = db.scalars(
            select(AiUsage).where(AiUsage.user_id == user_id)
        ).one()
    finally:
        db.close()

    assert counter.count == 1
    assert len(logs) == 1
    assert logs[0].metadata_json["ai_layer"] == "L2_REASON"
    assert legacy_usage.endpoint == "l2_reason_pattern_check"
