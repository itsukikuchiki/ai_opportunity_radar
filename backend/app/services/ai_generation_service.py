from __future__ import annotations

from collections import Counter
from typing import Any

from app.schemas.ai_schema import (
    CaptureReplyResponse,
    DeepWeeklyRequest,
    DeepWeeklyResponse,
    JourneyGenerateRequest,
    JourneyGenerateResponse,
    LightDialogResponse,
    OpportunitySnapshotSchema,
    TodaySummaryRequest,
    TodaySummaryResponse,
    WeeklyGenerateRequest,
    WeeklyGenerateResponse,
    WeeklyInsightItem,
)
from app.services.classification_service import ClassificationService


class AiGenerationService:
    def __init__(self) -> None:
        self.classification_service = ClassificationService()

    def generate_capture_reply(self, payload: dict[str, Any]) -> CaptureReplyResponse:
        content = (payload.get("content") or "").strip()
        recent_assistant_texts = payload.get("recent_assistant_texts") or []

        if not content:
            raise ValueError("content is required")

        if self._is_immediate_safety_risk(content):
            return CaptureReplyResponse(
                acknowledgement=self._immediate_safety_reply(),
                observation="先确认你现在是否处于立即危险中。",
                try_next="请先联系当地紧急服务，或一个能马上到你身边的可信任的人。",
                emotion="negative",
                intensity="high",
                scene_tags=[],
                intent_tags=["immediate_safety"],
                followup=None,
            )

        analysis = self._analyze_capture(content)
        response_style = payload.get('response_style') or 'gentle'
        reply_bundle = self._build_reply_bundle(
            content=content,
            emotion=analysis["emotion"],
            intensity=analysis["intensity"],
            scene_tags=analysis["scene_tags"],
            intent_tags=analysis["intent_tags"],
            recent_assistant_texts=recent_assistant_texts,
            response_style=response_style,
        )

        return CaptureReplyResponse(
            acknowledgement=reply_bundle["acknowledgement"],
            observation=reply_bundle["observation"],
            try_next=reply_bundle["try_next"],
            emotion=analysis["emotion"],
            intensity=analysis["intensity"],
            scene_tags=analysis["scene_tags"],
            intent_tags=analysis["intent_tags"],
            followup=None,
        )

    def generate_today_summary(
        self,
        request: TodaySummaryRequest,
    ) -> TodaySummaryResponse:
        entries = request.entries
        count = request.entry_count or len(entries)
        response_style = request.response_style or 'gentle'

        if count <= 0 or not entries:
            return TodaySummaryResponse(
                observation="今天还没有记录，先留下一件真实发生的小事就好。",
                suggestion="今天先记下一件让你停顿了一下的小事就好。",
            )

        contents = [e.content.strip() for e in entries if e.content and e.content.strip()]
        if not contents:
            return TodaySummaryResponse(
                observation="今天先把一件真实发生的小事留在这里就好。",
                suggestion="不用急着整理，先记住今天最让你停顿的一下。",
            )

        analyses = [self._analyze_capture(content) for content in contents]
        dominant_emotion = self._dominant_emotion(analyses)
        scene_focus = self._top_scene_tag(analyses)
        top_theme = self._top_theme(contents)

        if count == 1:
            if dominant_emotion == "positive":
                observation = f"今天记录了 1 条，你有一个真正让自己感觉变好的片段，线索落在“{top_theme}”上。"
                suggestion = "先把那个让你感觉不错的具体点记住，之后它会很有参考价值。"
            elif dominant_emotion == "mixed":
                observation = f"今天记录了 1 条，这不是单纯的好或不好，而是有一股来回拉扯的感觉，线索落在“{top_theme}”上。"
                suggestion = "先别急着总结整天，只记住是什么让你后面稍微缓回来一点。"
            elif dominant_emotion == "negative":
                observation = f"今天记录了 1 条，更明显的不是情绪本身，而是“{scene_focus or top_theme}”这个场景在消耗你。"
                suggestion = "下次它再出现时，只补一句发生在什么场景就够了。"
            else:
                observation = f"今天记录了 1 条，你已经把一个值得留意的线索放下来了，最明显的是“{top_theme}”。"
                suggestion = "先留意它之后还会不会再出现，不用急着解释。"
        else:
            if dominant_emotion == "positive":
                observation = f"今天记录了 {count} 条，几条线索都更偏向让你恢复能量的方向，最明显的主题是“{top_theme}”。"
                suggestion = "今天可以先试试：记住哪一类小事最容易把你往好的状态拉回来。"
            elif dominant_emotion == "mixed":
                observation = f"今天记录了 {count} 条，几条线索不是同向变化，而是在“{top_theme}”附近来回拉扯。"
                suggestion = "今天先留意：哪些场景会把你拉低，哪些小事又会把你拉回来。"
            elif dominant_emotion == "negative":
                observation = f"今天记录了 {count} 条，几条线索开始集中到“{scene_focus or top_theme}”这个消耗点上。"
                suggestion = f"今天可以先试试：下次再出现“{scene_focus or top_theme}”时，用一句话补记它发生在什么场景。"
            else:
                observation = f"今天记录了 {count} 条，几条线索已经开始往“{top_theme}”上聚。"
                suggestion = "先不用整理完整，只要继续把重复出现的那类瞬间记下来。"

        return TodaySummaryResponse(
            observation=self._style_text(observation, response_style, kind='observation').strip(),
            suggestion=self._style_text(suggestion, response_style, kind='suggestion').strip(),
        )

    def generate_weekly_summary(
        self,
        request: WeeklyGenerateRequest,
    ) -> WeeklyGenerateResponse:
        if request.entry_count <= 0 or not request.entries:
            return WeeklyGenerateResponse(
                week_start=request.week_start,
                week_end=request.week_end,
                status="insufficient_data",
                key_insight=None,
                patterns=[],
                frictions=[],
                best_action=None,
                opportunity_snapshot=None,
                feedback_submitted=False,
            )

        contents = [entry.content.strip() for entry in request.entries if entry.content and entry.content.strip()]
        top_token = self._evidence_topic(contents=contents, top_tokens=request.top_tokens)
        peak_day = self._peak_day(request.day_counts)
        behavior_hint = self._weekly_illustration_hint(
            " ".join([top_token, *contents]),
            fallback="只是观察也有帮助",
        )
        friction_hint = self._weekly_illustration_hint(
            " ".join([top_token, peak_day, *contents]),
            fallback="任务堆积，开始变困难",
        )
        confidence_line = (
            "基于目前少量信号，先把它当成临时观察。"
            if request.entry_count < 4
            else "这周已经有足够线索，可以先看它的重复方式。"
        )

        patterns = [
            WeeklyInsightItem(
                name=f"本周小观察：{top_token}",
                summary=f"{confidence_line} 记录里最先浮出来的是“{top_token}”，先看它在哪些场景里回来。",
                illustration_hint=behavior_hint,
            ),
            WeeklyInsightItem(
                name="证据来源",
                summary=self._evidence_summary(contents=contents, fallback=top_token),
                illustration_hint="只是观察也有帮助",
            ),
        ]

        frictions = [
            WeeklyInsightItem(
                name="本周可能的消耗点",
                summary=f"目前先看“{top_token}”带来的负担；其中 {peak_day} 的信号更集中，但还不需要当成结论。",
                illustration_hint=friction_hint,
            ),
        ]

        best_action = f"这周先试一步：下次再出现“{top_token}”时，用一句话补记它发生在什么场景。"

        opportunity_snapshot = OpportunitySnapshotSchema(
            name="把重复信号固定下来",
            summary=f"如果“{top_token}”之后还会回来，它适合先被结构化记录，再决定要不要调整。",
            illustration_hint="只是观察也有帮助",
        )

        return WeeklyGenerateResponse(
            week_start=request.week_start,
            week_end=request.week_end,
            status="ready",
            key_insight=f"{confidence_line} 这周先看“{top_token}”，{peak_day} 的信号更密集。",
            patterns=patterns,
            frictions=frictions,
            best_action=best_action,
            opportunity_snapshot=opportunity_snapshot,
            feedback_submitted=False,
        )

    def _weekly_illustration_hint(self, text: str, *, fallback: str) -> str:
        source = text.lower()
        rules = [
            (["任务", "堆", "太多", "todo"], "任务堆积，开始变困难"),
            (["会议", "开会"], "会议密集，注意力被切碎"),
            (["临时", "变化", "打断"], "临时变化打断原本节奏"),
            (["休息", "恢复", "挤"], "休息时间被任务挤掉"),
            (["空转", "停不下来"], "想休息，但停下来后反而空转"),
            (["手机", "短视频", "刷"], "晚上刷手机变多"),
            (["早上", "启动"], "早上启动困难"),
            (["中午", "午后", "下午", "精力"], "中午以后精力明显下降"),
            (["日程", "安排", "密度"], "情绪被日程密度带着走"),
            (["焦虑", "紧张", "还没开始"], "焦虑提前出现，还没开始就紧张"),
            (["完成", "做完", "更累"], "做完事后更累，不是更轻松"),
            (["计划", "目标", "太大"], "计划越大，越容易不开始"),
            (["分散", "目标太多"], "目标太多，注意力分散"),
            (["创作", "创造", "工作"], "创作被工作挤掉"),
            (["拒绝", "边界", "自己的时间"], "不敢拒绝，自己的时间被挤占"),
            (["迎合", "疲惫"], "过度迎合后感到疲惫"),
            (["表达", "说不清"], "想表达，但说不清"),
            (["独处"], "独处不足，恢复变慢"),
            (["环境", "房间", "混乱"], "生活环境混乱，心情也乱"),
            (["关系", "对话", "内耗"], "关系对话后反复内耗"),
            (["金钱", "钱", "现实压力"], "金钱或现实压力牵动安全感"),
            (["身体", "累"], "身体信号先出现，才意识到累"),
            (["有效", "稳定"], "小行动有效，节奏开始稳定"),
            (["兴趣", "爱好"], "兴趣活动带来恢复感"),
        ]
        for tokens, hint in rules:
            if any(token in source for token in tokens):
                return hint
        return fallback

    def generate_light_dialog(self, request) -> LightDialogResponse:
        capture_content = request.capture_content.strip()
        user_message = request.user_message.strip()
        if not capture_content or not user_message:
            raise ValueError("capture_content and user_message are required")

        history_text = " ".join(turn.text for turn in request.history)
        safety_text = " ".join(
            part for part in (capture_content, history_text, user_message) if part
        )
        if self._is_immediate_safety_risk(safety_text):
            return LightDialogResponse(
                reply=self._immediate_safety_reply(),
                suggested_prompts=[
                    "我现在处于立即危险中",
                    "我没有立即危险，但需要有人陪我",
                    "我可以先联系一个可信任的人",
                ],
            )

        analysis = self._analyze_capture(capture_content)
        emotion = analysis["emotion"]
        response_style = request.response_style or 'gentle'
        history_len = len(request.history)

        if history_len <= 1:
            prefix = {
                "negative": "听起来这一下确实让你有些难受，我先接住你现在说的这部分。",
                "mixed": "这条里有些拉扯感，我们先不用急着把它解释完整。",
                "positive": "这个片刻对你有一点分量，值得先好好留下。",
            }.get(emotion, "我在听，我们先只看你现在最想说的这一点。")
        else:
            prefix = "我继续听着你刚才那句。"

        if any(token in user_message for token in ["为什么", "為什麼", "why"]):
            answer = f"{prefix}现在的这一条还不足以替你判断原因。可以先说说：事情本身和它带给你的感受，哪一部分此刻更重一点？"
        elif any(token in user_message for token in ["怎么办", "怎麼辦", "怎么办啊", "what should", "怎么办呢"]):
            answer = f"{prefix}先不用一次解决整件事。你愿意的话，我们只找一个现在负担最小、能让你稍微稳一点的动作。"
        elif any(token in user_message for token in ["其实", "其實", "其实是", "actually"]):
            answer = f"{prefix}你补的这句让重点更清楚了一点。哪一部分是你最不想被轻轻带过的？"
        else:
            answer = f"{prefix}如果愿意，可以只补一句：当时最让你停住的是哪个瞬间？"

        prompts = [
            "我最卡住的是哪一个瞬间？",
            "这件事让我不舒服的核心是什么？",
            "下次再遇到时我想先做什么？",
        ]
        return LightDialogResponse(reply=self._style_text(answer, response_style, kind='reply'), suggested_prompts=prompts)

    def _is_immediate_safety_risk(self, text: str) -> bool:
        return self.classification_service.is_immediate_safety_risk(text)

    def _immediate_safety_reply(self) -> str:
        return self.classification_service.immediate_safety_acknowledgement()

    def generate_deep_weekly(self, request: DeepWeeklyRequest) -> DeepWeeklyResponse:
        pattern_name = self._pick_name(request.patterns, fallback="这周反复回来的主题")
        friction_name = self._pick_name(request.frictions, fallback="这周最稳定的消耗点")
        key_insight = (request.key_insight or "").strip() or f"这周的记录在“{pattern_name}”附近逐渐聚起来。"

        peak_day = "这周中段"
        low_day = "这周某个低点"
        rebound_phrase = "后半段还没有足够证据说明已经回弹"
        chart_data = request.chart_data or []
        if chart_data:
            peak = max(chart_data, key=lambda item: item.get("signal_count", 0))
            low = min(chart_data, key=lambda item: item.get("mood_score", 0))
            last = chart_data[-1]
            peak_day = str(peak.get("date") or peak_day)
            low_day = str(low.get("date") or low_day)
            if len(peak_day) >= 10 and "-" in peak_day:
                peak_day = peak_day[5:]
            if len(low_day) >= 10 and "-" in low_day:
                low_day = low_day[5:]
            if last.get("mood_score", 0) > low.get("mood_score", 0):
                rebound_phrase = "后半段有一点回收，说明这一周不是一路往下掉，而是有被拉回来一点"

        summary = (
            f"{key_insight} L3 Reflect 要看的更像是结构："
            f"“{pattern_name}”并不是孤立出现，它和“{friction_name}”在同一周里互相牵住，"
            "让你反复在想推进和被消耗之间切换。"
        )
        root_tension = (
            f"表层事件是几条不同记录；底层 tension 是你想让“{pattern_name}”更顺一点，"
            f"但每次靠近时，“{friction_name}”又把注意力拉走。所以真正累的不是某一天，"
            "而是不断重启判断、不断重新找回节奏。"
        )
        hidden_pattern = (
            f"把图和文字放在一起看，{peak_day} 是线索密度更高的节点，{low_day} 更像状态低点。"
            f"{rebound_phrase}。这说明本周的重点不是简单问“哪天最糟”，而是看压力聚集后，"
            "你有没有机会把自己重新带回比较可判断的位置。"
        )
        next_focus = (
            f"下周先不要扩大观察面，只盯一个小问题：当“{friction_name}”再次出现时，"
            f"它是在打断“{pattern_name}”的开始、推进中段，还是收尾阶段。这个位置比事件本身更值得记。"
        )
        risk_note = "这份 L3 Reflect 更适合拿来收窄注意力，不适合一次解释完整个自己；如果这一周本来就很早期，它只能给方向，不能当结论。"
        key_nodes = [
            f"重复主题：{pattern_name}",
            f"主要摩擦：{friction_name}",
            f"线索密集点：{peak_day}",
            f"走势低点：{low_day}",
        ]
        return DeepWeeklyResponse(
            summary=summary,
            root_tension=root_tension,
            hidden_pattern=hidden_pattern,
            next_focus=next_focus,
            risk_note=risk_note,
            key_nodes=key_nodes,
        )

    def _pick_name(self, items, fallback: str) -> str:
        if not items:
            return fallback
        first = items[0]
        if isinstance(first, dict):
            name = str(first.get("name") or "").strip()
            return name or fallback
        name = getattr(first, "name", "")
        return name.strip() or fallback

    def generate_journey_summary(
        self,
        request: JourneyGenerateRequest,
    ) -> JourneyGenerateResponse:
        contents = [entry.content.strip() for entry in request.entries if entry.content and entry.content.strip()]
        top_token = self._evidence_topic(contents=contents, top_tokens=request.top_tokens)
        total_days = max(request.total_days, 1)
        confidence = "还只是早期生活轨迹" if request.entry_count < 6 else "已经开始有长期线索"

        return JourneyGenerateResponse(
            patterns=[
                WeeklyInsightItem(
                    name="正在形成的生活路径",
                    summary=f"{confidence}：目前最清楚的是“{top_token}”。先看它是偶尔出现，还是慢慢变成重复结构。",
                )
            ],
            frictions=[
                WeeklyInsightItem(
                    name="可能的长期消耗",
                    summary=f"如果“{top_token}”继续出现，它可能是后面要回看的消耗来源；现在先保持轻观察。",
                )
            ],
            desires=[
                WeeklyInsightItem(
                    name="还在浮现的方向",
                    summary=f"记录已经跨越 {total_days} 天，先从真实记录里看哪些事让你想恢复、期待或离开消耗。",
                )
            ],
            experiments=[
                WeeklyInsightItem(
                    name="Review & Adjust 入口",
                    summary="后续实验反馈会和这些记录放在一起看：有效、偏难、跳过都只是证据，不是失败。",
                )
            ],
        )

    def generate_followup_question(self, payload: dict[str, Any]) -> dict[str, Any]:
        return {
            "question_type": "information_friction_detail",
            "question_text": "你最烦的是找资料，还是整理结构？",
            "options": [
                {"label": "找资料", "value": "find_info"},
                {"label": "整理结构", "value": "organize_structure"},
                {"label": "重新写", "value": "rewrite"},
                {"label": "先跳过", "value": "skip"},
            ],
        }

    def _analyze_capture(self, content: str) -> dict[str, Any]:
        normalized = self._normalize_text(content)

        positive_keywords = {
            "开心", "高兴", "喜欢", "顺利", "放松", "舒服", "满足", "期待", "有成就感",
            "开心了", "轻松", "好吃", "快乐", "愉快", "安心", "踏实",
            "嬉しい", "楽しい", "よかった", "満足", "安心", "嬉しかった",
            "happy", "glad", "good", "great", "relieved", "enjoyed", "nice",
        }
        negative_keywords = {
            "烦", "累", "崩", "难受", "焦虑", "生气", "压力", "不想", "麻烦", "受不了",
            "被打断", "烦躁", "委屈", "失控", "糟糕", "痛苦", "压抑", "慌",
            "しんどい", "つらい", "疲れた", "イライラ", "不安", "最悪", "むかつく",
            "annoyed", "tired", "upset", "angry", "anxious", "stressed", "frustrated",
        }
        mixed_markers = {
            "但是", "但", "不过", "后来", "虽然", "又", "缓回来", "好了一点", "一边",
            "けど", "でも", "ただ", "そのあと", "一方で",
            "but", "however", "though", "yet", "later",
        }

        pos_hits = self._keyword_hits(normalized, positive_keywords)
        neg_hits = self._keyword_hits(normalized, negative_keywords)
        mixed_hits = self._keyword_hits(normalized, mixed_markers)

        if pos_hits > 0 and neg_hits > 0:
            emotion = "mixed"
        elif mixed_hits > 0 and (pos_hits > 0 or neg_hits > 0):
            emotion = "mixed"
        elif neg_hits > 0:
            emotion = "negative"
        elif pos_hits > 0:
            emotion = "positive"
        else:
            emotion = "neutral"

        strong_markers = {
            "一直", "总是", "反复", "受不了", "崩了", "特别", "非常", "真的", "很烦", "很累",
            "ずっと", "かなり", "本当に", "めちゃくちゃ",
            "very", "really", "so much", "extremely",
        }
        medium_markers = {
            "有点", "有一些", "有一点", "有些", "稍微", "有点点",
            "ちょっと", "少し",
            "a bit", "kind of", "somewhat",
        }

        if self._keyword_hits(normalized, strong_markers) > 0 or "！" in content or "!" in content:
            intensity = "high"
        elif self._keyword_hits(normalized, medium_markers) > 0 or pos_hits + neg_hits > 0:
            intensity = "medium"
        else:
            intensity = "low"

        scene_rules = {
            "work": {"上班", "开会", "同事", "老板", "需求", "任务", "公司", "工作", "邮件", "汇报", "会议", "職場", "仕事", "会議", "task", "work", "meeting", "manager"},
            "commute": {"通勤", "地铁", "电车", "路上", "回家路上", "出门", "満員電車", "通勤", "on the way", "commute", "train"},
            "relationship": {"朋友", "家人", "恋人", "同事关系", "相处", "聊天", "关系", "人間関係", "family", "friend", "partner"},
            "body": {"头疼", "困", "睡", "累", "身体", "胃", "月经", "不舒服", "健康", "体調", "眠い", "body", "health"},
            "money": {"花钱", "工资", "金钱", "消费", "买", "预算", "お金", "支出", "money", "budget", "spent"},
            "cost": {"token", "tokens", "贵", "成本", "价格", "花费", "expensive", "cost"},
            "rest": {"休息", "放松", "睡觉", "午休", "恢复", "发呆", "散步", "休憩", "rest", "relax"},
            "future": {"明天", "未来", "预测", "当下", "明日", "予測", "tomorrow", "future", "present"},
            "hobby": {"骑马", "乗馬", "horse", "ride"},
            "achievement": {"完成", "做完", "推进", "成果", "达成", "有进展", "進んだ", "達成", "finished", "done"},
            "self_doubt": {"怀疑自己", "自我否定", "不够好", "没做好", "担心自己", "自信", "自信がない", "self doubt", "not good enough"},
            "daily_friction": {"被打断", "重复", "麻烦", "卡住", "拖延", "琐事", "不顺", "切り替え", "interrupted", "blocked", "friction"},
            "home": {"在家", "回家", "房间", "家里", "家务", "家", "家で", "home"},
            "study": {"学习", "看书", "复习", "考试", "输出", "写作", "勉強", "study", "reading", "writing"},
            "daily_life": {"吃饭", "好吃", "逛", "买东西", "天气", "散步", "咖啡", "食べた", "lunch", "coffee"},
        }

        scene_tags: list[str] = []
        for scene, keywords in scene_rules.items():
            if self._keyword_hits(normalized, keywords) > 0:
                scene_tags.append(scene)

        if not scene_tags:
            scene_tags = ["daily_friction"] if emotion == "negative" else ["daily_life"]

        intent_tags: list[str] = []
        if emotion == "negative":
            intent_tags.append("vent")
        if emotion == "positive":
            intent_tags.append("celebrate")
        if emotion == "mixed":
            intent_tags.extend(["vent", "reflection"])
        if not intent_tags:
            intent_tags.append("record")

        reflection_markers = {"为什么", "是不是", "感觉", "好像", "也许", "maybe", "wonder", "気がする"}
        decision_markers = {"要不要", "要不要做", "要不要继续", "决定", "算了", "whether", "decide", "決める"}

        if self._keyword_hits(normalized, reflection_markers) > 0 and "reflection" not in intent_tags:
            intent_tags.append("reflection")
        if self._keyword_hits(normalized, decision_markers) > 0 and "decision" not in intent_tags:
            intent_tags.append("decision")

        return {
            "emotion": emotion,
            "intensity": intensity,
            "scene_tags": scene_tags[:3],
            "intent_tags": intent_tags[:3],
        }

    def _build_reply_bundle(
        self,
        content: str,
        emotion: str,
        intensity: str,
        scene_tags: list[str],
        intent_tags: list[str],
        recent_assistant_texts: list[str] | None = None,
        response_style: str = 'gentle',
    ) -> dict[str, str]:
        recent_assistant_texts = recent_assistant_texts or []

        try:
            acknowledgement = self.classification_service.generate_acknowledgement(
                content=content,
                recent_assistant_texts=recent_assistant_texts,
            )
            if not isinstance(acknowledgement, str) or not acknowledgement.strip():
                raise ValueError("empty acknowledgement")
        except Exception:
            acknowledgement = self._fallback_acknowledgement(
                content=content,
                emotion=emotion,
                intensity=intensity,
                scene_tags=scene_tags,
            )

        observation = self._fallback_observation(
            content=content,
            emotion=emotion,
            scene_tags=scene_tags,
        )
        try_next = self._fallback_try_next(
            content=content,
            emotion=emotion,
            scene_tags=scene_tags,
            intent_tags=intent_tags,
        )
        topic = self.classification_service._topic_hint(content)
        if topic:
            observation = self._topic_observation(topic=topic)
            try_next = self._topic_try_next(topic=topic)

        return {
            "acknowledgement": self._style_text(acknowledgement.strip(), response_style, kind='acknowledgement'),
            "observation": self._style_text(observation.strip(), response_style, kind='observation'),
            "try_next": self._style_text(try_next.strip(), response_style, kind='suggestion'),
        }

    def _topic_observation(self, *, topic: str) -> str:
        if topic == "cost":
            return "这条更像是成本提醒：当 token 或 AI 使用成本变得显眼，它会影响你对工具是否值得继续用的判断。"
        if topic == "horse_expectation":
            return "这条的恢复线索很明确：骑马不是普通安排，而是你这周少数真正期待的事情。"
        if topic == "tomorrow_uncertainty":
            return "这条更像是一种生活视角：明天不可控，所以今天能抓住的当下变得更重要。"
        if topic == "retirement_wish":
            return "这条不是简单抱怨，它更像是在提示：现在的工作消耗已经让你开始想象彻底离开的生活。"
        if topic == "weather_good":
            return "这条里的正向线索很小但清楚：外部环境变轻，会让今天更容易松一点。"
        if topic == "rest_wish":
            return "这条更像是恢复需求浮出来了：你可能不是懒，而是确实想要一点不用继续扛的空间。"
        if topic == "money":
            return "这条和钱有关，也可能牵着安全感、值不值得、以及资源是否够用的判断。"
        return "这条可以先作为一个具体线索留下来。"

    def _topic_try_next(self, *, topic: str) -> str:
        if topic == "cost":
            return "可以先记一笔：这次让你觉得贵的，是单次花费、持续消耗，还是不确定能不能换来价值。"
        if topic == "horse_expectation":
            return "可以先补一句：骑马让你期待的到底是身体活动、自由感，还是暂时离开日常压力。"
        if topic == "tomorrow_uncertainty":
            return "今天不用把明天想清楚，只选一件当下能好好做的小事就够了。"
        if topic == "retirement_wish":
            return "先不用立刻讨论退休，只补一句：最想离开的到底是工作量、节奏，还是长期没有恢复空间。"
        if topic == "weather_good":
            return "如果可以，今天留意一下：天气变好后，你更想散步、休息，还是做一点轻松的事。"
        if topic == "rest_wish":
            return "先给自己一个很小的恢复块：哪怕只是十分钟不输入、不处理、不回应。"
        if topic == "money":
            return "先记清楚这笔钱让你卡住的点：价格、必要性，还是付出之后的确定感。"
        return "先看看它之后还会不会再回来。"


    def _style_text(self, text: str, response_style: str, kind: str = 'reply') -> str:
        text = (text or '').strip()
        if not text:
            return text

        if response_style == 'direct':
            if kind == 'acknowledgement':
                direct_prefix = '先说重点：'
            elif kind == 'suggestion':
                direct_prefix = '下一步：'
            else:
                direct_prefix = '重点是：'
            return f"{direct_prefix}{text}" if not text.startswith(direct_prefix) else text

        if response_style == 'clear':
            if kind == 'suggestion':
                clear_prefix = '更清楚地说，'
            elif kind == 'acknowledgement':
                clear_prefix = '换句话说，'
            else:
                clear_prefix = '更具体一点，'
            return f"{clear_prefix}{text}" if not text.startswith(clear_prefix) else text

        return text

    def _fallback_acknowledgement(
        self,
        content: str,
        emotion: str,
        intensity: str,
        scene_tags: list[str],
    ) -> str:
        scene = scene_tags[0] if scene_tags else "daily_life"

        if emotion == "positive":
            if scene == "achievement":
                return "这一下不是普通地“还不错”，而是你真的感受到一点推进和成形。"
            if scene == "daily_life":
                return "这条里有一个很具体的小好时刻，被你好好接住了。"
            return "这一下确实有把你往好的状态里带一点，不只是轻轻划过去。"

        if emotion == "mixed":
            if scene in {"work", "daily_friction"}:
                return "这条里能感觉到你先被拉扯了一下，后面又靠一点具体的小事缓回来一些。"
            return "这不是单纯的好或不好，更像是一整段状态在来回拉扯。"

        if emotion == "negative":
            if scene == "work":
                return "这一下更像是工作里的节奏或失控感在消耗你，难怪会觉得烦。"
            if scene == "commute":
                return "这条里那股不顺和消耗感很明显，像是整个人都被路上的状态拖住了一下。"
            if scene == "body":
                return "这一下更像是身体和情绪一起在往下掉，先不用急着把它想明白。"
            return "这一下听起来确实挺消耗人的，先把它放在这里就好。"

        return "先把这一条留在这里也很好，它本身就是一个值得继续看的线索。"

    def _fallback_observation(
        self,
        content: str,
        emotion: str,
        scene_tags: list[str],
    ) -> str:
        scene = scene_tags[0] if scene_tags else "daily_life"

        if emotion == "positive":
            if scene == "achievement":
                return "今天比较值得记住的，是你会被“确实有推进”的感觉明显提起来。"
            return "今天更清楚的线索是：一些具体的小好事，确实能给你补回状态。"

        if emotion == "mixed":
            if scene in {"work", "daily_friction"}:
                return "你今天不是单向下滑，而是先被具体场景消耗，再被别的小片段慢慢拉回来。"
            return "这条里最值得记的是那种拉扯感：你会被消耗，也会被一些具体的东西重新接住。"

        if emotion == "negative":
            if scene == "work":
                return "今天更明显的不是情绪本身，而是工作里的打断、改动或失控感在反复磨你。"
            if scene == "commute":
                return "这条里最清楚的线索，是通勤或路上的状态会明显拖低你的能量。"
            if scene == "body":
                return "你今天更像是先被身体状态拖住了，情绪只是跟着一起往下。"
            return "今天更明显的不是一句“烦”，而是某个具体场景正在稳定地消耗你。"

        return "你今天更像是在留下一条状态线索，而不是在表达一股很强的情绪。"

    def _fallback_try_next(
        self,
        content: str,
        emotion: str,
        scene_tags: list[str],
        intent_tags: list[str],
    ) -> str:
        scene = scene_tags[0] if scene_tags else "daily_life"

        if emotion == "positive":
            if scene == "achievement":
                return "先记住这一下具体是因为什么推进感出现的，之后很容易复用。"
            return "先把让你感觉不错的那个具体点记下来，不用写多。"

        if emotion == "mixed":
            return "今天先别急着总结整天，只记住是什么让你后面稍微缓回来一点。"

        if emotion == "negative":
            if scene == "work":
                return "下次再出现时，只补一句它发生在什么工作场景里，就已经很有用了。"
            if scene == "commute":
                return "先记住最卡的那一段路上发生了什么，其他今天先放一放。"
            if scene == "body":
                return "先不用分析原因，只留意一下这种身体状态是从什么时候开始的。"
            return "先把最卡你的那个瞬间记下来，其他先不用整理。"

        if "decision" in intent_tags:
            return "先不要急着下结论，留意这件事之后还会不会再出现一次。"

        return "先把这一条放着，看看之后它会不会再回来。"

    def _dominant_emotion(self, analyses: list[dict[str, Any]]) -> str:
        if not analyses:
            return "neutral"

        counter = Counter(item["emotion"] for item in analyses if item.get("emotion"))
        if not counter:
            return "neutral"

        if counter.get("mixed", 0) > 0:
            return "mixed"
        return counter.most_common(1)[0][0]

    def _top_scene_tag(self, analyses: list[dict[str, Any]]) -> str | None:
        counter: Counter[str] = Counter()
        for item in analyses:
            for tag in item.get("scene_tags", []):
                if tag:
                    counter[tag] += 1
        if not counter:
            return None
        return counter.most_common(1)[0][0]

    def _top_theme(self, contents: list[str]) -> str:
        if not contents:
            return "今天的线索"
        tokens = self._tokenize(contents)
        if not tokens:
            trimmed = contents[0][:10]
            return trimmed if trimmed else "今天的线索"
        return tokens[0]

    def _safe_top_token(self, top_tokens: list[str]) -> str:
        for token in top_tokens:
            token = token.strip()
            if token:
                return token
        return "最近的记录"

    def _evidence_topic(self, *, contents: list[str], top_tokens: list[str]) -> str:
        joined = " ".join(contents).lower()
        topic = self.classification_service._topic_hint(joined)
        if topic == "cost":
            return "token 成本"
        if topic == "horse_expectation":
            return "骑马带来的期待和恢复"
        if topic == "tomorrow_uncertainty":
            return "明天不可控与活在当下"
        if topic == "retirement_wish":
            return "想离开工作消耗"
        if topic == "weather_good":
            return "天气带来的轻一点的状态"
        if topic == "rest_wish":
            return "想停下来休息"
        if topic == "money":
            return "钱和成本压力"
        return self._safe_top_token(top_tokens)

    def _evidence_summary(self, *, contents: list[str], fallback: str) -> str:
        samples = [item for item in contents if item][:2]
        if not samples:
            return f"目前证据还少，先把“{fallback}”作为待观察线索。"
        if len(samples) == 1:
            return f"目前主要来自一条记录：“{samples[0][:28]}”。先不要过度判断。"
        return f"目前主要来自这些记录：“{samples[0][:18]}”和“{samples[1][:18]}”。先看它们是否还会重复。"

    def _peak_day(self, day_counts: dict[str, int]) -> str:
        if not day_counts:
            return "这周"
        return max(day_counts.items(), key=lambda x: x[1])[0]

    def _tokenize(self, texts: list[str]) -> list[str]:
        counter: Counter[str] = Counter()

        stop_words = {
            "今天", "还是", "有点", "就是", "然后", "最近", "一直", "一个",
            "the", "and", "for", "that", "this", "with", "have", "just", "today",
            "して", "いる", "こと", "もの", "これ", "それ", "ただ",
        }

        for text in texts:
            normalized = (
                text.lower()
                .replace("，", " ")
                .replace("。", " ")
                .replace("、", " ")
                .replace(",", " ")
                .replace(".", " ")
                .replace("！", " ")
                .replace("？", " ")
                .replace("!", " ")
                .replace("?", " ")
                .replace(":", " ")
                .replace("：", " ")
            )
            parts = [p.strip() for p in normalized.split() if p.strip()]
            for part in parts:
                if len(part) < 2:
                    continue
                if part in stop_words:
                    continue
                counter[part] += 1

        return [token for token, _ in counter.most_common(10)]

    def _normalize_text(self, text: str) -> str:
        return (
            (text or "")
            .lower()
            .replace("，", " ")
            .replace("。", " ")
            .replace("、", " ")
            .replace(",", " ")
            .replace(".", " ")
            .replace("！", " ! ")
            .replace("？", " ? ")
            .replace(":", " ")
            .replace("：", " ")
        )

    def _keyword_hits(self, text: str, keywords: set[str]) -> int:
        hits = 0
        for kw in keywords:
            if kw and kw in text:
                hits += 1
        return hits
