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
    MonthlyBridgeWeekSchema,
    MonthlyGenerateRequest,
    MonthlyGenerateResponse,
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

    def _request_language(
        self,
        requested_language: str | None,
        entries: list[Any] | None = None,
    ) -> str:
        content = " ".join(
            str(getattr(entry, "content", "") or "").strip()
            for entry in (entries or [])
            if str(getattr(entry, "content", "") or "").strip()
        )
        return self.classification_service.normalize_language(
            requested_language,
            content=content,
        )

    def generate_capture_reply(self, payload: dict[str, Any]) -> CaptureReplyResponse:
        content = (payload.get("content") or "").strip()
        recent_assistant_texts = payload.get("recent_assistant_texts") or []

        if not content:
            raise ValueError("content is required")

        language = self.classification_service.normalize_language(
            payload.get("language"),
            content=content,
        )
        if self._is_immediate_safety_risk(content):
            safety_copy = self._capture_safety_copy(language)
            return CaptureReplyResponse(
                acknowledgement=self._immediate_safety_reply(language),
                observation=safety_copy["observation"],
                try_next=safety_copy["try_next"],
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
            language=language,
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
        language = self._request_language(request.language, entries)

        if count <= 0 or not entries:
            empty_copy = {
                "zh-Hans": (
                    "今天还没有记录，先留下一件真实发生的小事就好。",
                    "今天先记下一件让你停顿了一下的小事就好。",
                ),
                "zh-Hant": (
                    "今天還沒有記錄，先留下一件真實發生的小事就好。",
                    "今天先記下一件讓你停頓了一下的小事就好。",
                ),
                "ja": (
                    "今日はまだ記録がありません。実際にあった小さな出来事を一つだけ残してみましょう。",
                    "今日、少し立ち止まった出来事を一つだけ記録してみましょう。",
                ),
                "en": (
                    "There are no entries today yet. Start with one small thing that actually happened.",
                    "For today, note one moment that made you pause.",
                ),
            }[language]
            return TodaySummaryResponse(
                observation=empty_copy[0],
                suggestion=empty_copy[1],
            )

        contents = [e.content.strip() for e in entries if e.content and e.content.strip()]
        if not contents:
            empty_content_copy = {
                "zh-Hans": (
                    "今天先把一件真实发生的小事留在这里就好。",
                    "不用急着整理，先记住今天最让你停顿的一下。",
                ),
                "zh-Hant": (
                    "今天先把一件真實發生的小事留在這裡就好。",
                    "不用急著整理，先記住今天最讓你停頓的一下。",
                ),
                "ja": (
                    "今日は、実際にあった小さな出来事を一つ残すだけで十分です。",
                    "今は整理せず、今日いちばん立ち止まった瞬間だけ覚えておきましょう。",
                ),
                "en": (
                    "For today, it is enough to leave one small thing that actually happened.",
                    "There is no need to organize it yet; remember the moment that made you pause most.",
                ),
            }[language]
            return TodaySummaryResponse(
                observation=empty_content_copy[0],
                suggestion=empty_content_copy[1],
            )

        analyses = [self._analyze_capture(content) for content in contents]
        dominant_emotion = self._dominant_emotion(analyses)
        scene_focus = self._top_scene_tag(analyses)
        top_theme = self._top_theme(contents)

        if language != "zh-Hans":
            observation, suggestion = self._localized_today_summary(
                language=language,
                count=count,
                dominant_emotion=dominant_emotion,
                scene_focus=scene_focus,
                top_theme=top_theme,
            )
            return TodaySummaryResponse(
                observation=self._style_text(
                    observation,
                    response_style,
                    kind='observation',
                    language=language,
                ).strip(),
                suggestion=self._style_text(
                    suggestion,
                    response_style,
                    kind='suggestion',
                    language=language,
                ).strip(),
            )

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
            observation=self._style_text(
                observation,
                response_style,
                kind='observation',
                language=language,
            ).strip(),
            suggestion=self._style_text(
                suggestion,
                response_style,
                kind='suggestion',
                language=language,
            ).strip(),
        )

    def _localized_today_summary(
        self,
        *,
        language: str,
        count: int,
        dominant_emotion: str,
        scene_focus: str | None,
        top_theme: str,
    ) -> tuple[str, str]:
        focus = scene_focus or top_theme
        if language == "zh-Hant":
            if count == 1:
                copy = {
                    "positive": (
                        f"今天記錄了 1 條，你留下一個真正讓自己感覺變好的片段，Signal 落在「{top_theme}」。",
                        "先記住那個讓你感覺不錯的具體部分，之後會很有參考價值。",
                    ),
                    "mixed": (
                        f"今天記錄了 1 條，感受不是單純的好或不好，而是在「{top_theme}」附近來回拉扯。",
                        "先不用總結整天，只記住是什麼讓你後來稍微緩了回來。",
                    ),
                    "negative": (
                        f"今天記錄了 1 條，比情緒更明顯的是「{focus}」這個場景正在消耗你。",
                        "下次它再出現時，只補一句發生在什麼場景就好。",
                    ),
                    "neutral": (
                        f"今天記錄了 1 條，你已經留下一個值得注意的 Signal，最明顯的是「{top_theme}」。",
                        "先留意它之後會不會再出現，不用急著解釋。",
                    ),
                }
            else:
                copy = {
                    "positive": (
                        f"今天記錄了 {count} 條，幾條 Signal 都較偏向恢復，最明顯的主題是「{top_theme}」。",
                        "今天先記住哪一類小事最容易把你帶回較好的狀態。",
                    ),
                    "mixed": (
                        f"今天記錄了 {count} 條，幾條 Signal 並非同向變化，而是在「{top_theme}」附近來回拉扯。",
                        "今天先留意哪些場景會拉低你，哪些小事又會把你拉回來。",
                    ),
                    "negative": (
                        f"今天記錄了 {count} 條，幾條 Signal 開始集中到「{focus}」這個消耗點。",
                        f"下次再出現「{focus}」時，用一句話補記它發生在什麼場景。",
                    ),
                    "neutral": (
                        f"今天記錄了 {count} 條，幾條 Signal 已經開始往「{top_theme}」聚集。",
                        "先不用完整整理，只要繼續記下反覆出現的那類瞬間。",
                    ),
                }
            return copy.get(dominant_emotion, copy["neutral"])

        if language == "ja":
            if count == 1:
                copy = {
                    "positive": (
                        f"今日は 1 件記録しました。「{top_theme}」に、自分の調子がよくなった具体的な瞬間があります。",
                        "よい感覚につながった具体的な点だけ覚えておくと、あとで役立ちます。",
                    ),
                    "mixed": (
                        f"今日は 1 件記録しました。単純によい、悪いではなく、「{top_theme}」の周辺で気持ちが揺れています。",
                        "一日をまとめず、少し持ち直せたきっかけだけ覚えておきましょう。",
                    ),
                    "negative": (
                        f"今日は 1 件記録しました。感情そのものより、「{focus}」という場面が負担になっていることが見えます。",
                        "次に同じことが起きたら、どんな場面だったかを一言だけ足してみましょう。",
                    ),
                    "neutral": (
                        f"今日は 1 件記録しました。「{top_theme}」に、あとで見返したい Signal が残っています。",
                        "今は説明せず、また現れるかだけ見てみましょう。",
                    ),
                }
            else:
                copy = {
                    "positive": (
                        f"今日は {count} 件記録しました。複数の Signal が回復につながる方向を示し、中心は「{top_theme}」です。",
                        "どのような小さな出来事がよい状態へ戻してくれたか、覚えておきましょう。",
                    ),
                    "mixed": (
                        f"今日は {count} 件記録しました。複数の Signal は同じ方向ではなく、「{top_theme}」の周辺で揺れています。",
                        "負担になる場面と、少し持ち直せる出来事の両方を見てみましょう。",
                    ),
                    "negative": (
                        f"今日は {count} 件記録しました。複数の Signal が「{focus}」という負担に集まり始めています。",
                        f"次に「{focus}」が起きたら、どんな場面だったかを一言だけ残してみましょう。",
                    ),
                    "neutral": (
                        f"今日は {count} 件記録しました。複数の Signal が「{top_theme}」に集まり始めています。",
                        "今はまとめず、同じ種類の瞬間を引き続き残してみましょう。",
                    ),
                }
            return copy.get(dominant_emotion, copy["neutral"])

        if count == 1:
            copy = {
                "positive": (
                    f"You recorded 1 entry today. A genuinely restorative moment appears around “{top_theme}.”",
                    "Remember the specific detail that felt good; it may be useful later.",
                ),
                "mixed": (
                    f"You recorded 1 entry today. It is not simply good or bad; the tension sits around “{top_theme}.”",
                    "Do not summarize the whole day yet. Remember what helped you recover a little.",
                ),
                "negative": (
                    f"You recorded 1 entry today. More than the emotion itself, the “{focus}” situation seems to be draining you.",
                    "If it happens again, add one sentence about the situation.",
                ),
                "neutral": (
                    f"You recorded 1 entry today. A Signal worth watching appears around “{top_theme}.”",
                    "See whether it returns before trying to explain it.",
                ),
            }
        else:
            copy = {
                "positive": (
                    f"You recorded {count} entries today. Several Signals point toward recovery, especially around “{top_theme}.”",
                    "Notice which small experiences most reliably bring you back toward a better state.",
                ),
                "mixed": (
                    f"You recorded {count} entries today. The Signals move in different directions around “{top_theme}.”",
                    "Notice which situations drain you and which small moments help you recover.",
                ),
                "negative": (
                    f"You recorded {count} entries today. Several Signals are gathering around the drain of “{focus}.”",
                    f"When “{focus}” appears again, add one sentence about the situation.",
                ),
                "neutral": (
                    f"You recorded {count} entries today. Several Signals are beginning to gather around “{top_theme}.”",
                    "There is no need for a full summary yet; keep noting similar moments.",
                ),
            }
        return copy.get(dominant_emotion, copy["neutral"])

    def generate_weekly_summary(
        self,
        request: WeeklyGenerateRequest,
    ) -> WeeklyGenerateResponse:
        language = self._request_language(request.language, request.entries)
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
        top_token = self._evidence_topic(
            contents=contents,
            top_tokens=request.top_tokens,
            language=language,
        )
        peak_day = self._peak_day(request.day_counts)
        if language != "zh-Hans":
            return self._localized_weekly_summary(
                request=request,
                language=language,
                contents=contents,
                top_token=top_token,
                peak_day=peak_day,
            )
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
                trigger=self._weekly_pattern_trigger(
                    day_counts=request.day_counts,
                    top_token=top_token,
                ),
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

    def _localized_weekly_summary(
        self,
        *,
        request: WeeklyGenerateRequest,
        language: str,
        contents: list[str],
        top_token: str,
        peak_day: str,
    ) -> WeeklyGenerateResponse:
        text = " ".join([top_token, *contents])
        if language == "zh-Hant":
            early = "基於目前少量 Signal，先把它當成暫時觀察。"
            ready = "這週已經有足夠 Signal，可以先看它反覆出現的方式。"
            confidence = early if request.entry_count < 4 else ready
            pattern_name = f"本週小觀察：{top_token}"
            pattern_summary = f"{confidence} 記錄裡最先浮出來的是「{top_token}」，先看它在哪些場景回來。"
            friction_name = "本週可能的消耗點"
            friction_summary = f"目前先看「{top_token}」帶來的負擔；其中 {peak_day} 的 Signal 較集中，但還不需要當成結論。"
            action = f"這週先試一步：下次再出現「{top_token}」時，用一句話補記它發生在什麼場景。"
            snapshot_name = "把反覆出現的 Signal 固定下來"
            snapshot_summary = f"如果「{top_token}」之後還會回來，適合先結構化記錄，再決定是否調整。"
            insight = f"{confidence} 這週先看「{top_token}」，{peak_day} 的 Signal 較密集。"
            behavior_fallback = "只是觀察也有幫助"
            friction_fallback = "事情堆積，開始變得困難"
        elif language == "ja":
            early = "今は Signal がまだ少ないため、まずは暫定的な観察として見ます。"
            ready = "今週は十分な Signal があり、繰り返し方を見始められます。"
            confidence = early if request.entry_count < 4 else ready
            pattern_name = f"今週の小さな観察：{top_token}"
            pattern_summary = f"{confidence} 最初に見えてきたのは「{top_token}」です。どの場面で戻ってくるかを見ます。"
            friction_name = "今週の負担になりそうな点"
            friction_summary = f"今は「{top_token}」による負担を見ます。{peak_day} に Signal が多いものの、まだ結論にはしません。"
            action = f"今週は、「{top_token}」が再び現れたときに、どんな場面だったかを一文だけ残してみましょう。"
            snapshot_name = "繰り返す Signal を記録する"
            snapshot_summary = f"「{top_token}」がまた現れるなら、まず整理して記録し、その後で調整が必要かを考えます。"
            insight = f"{confidence} 今週は「{top_token}」を見ます。{peak_day} に Signal が多くなっています。"
            behavior_fallback = "観察するだけでも役に立つ"
            friction_fallback = "予定が重なり、始めにくくなる"
        else:
            early = "There are only a few Signals so far, so treat this as a tentative observation."
            ready = "There are enough Signals this week to begin looking at how the pattern repeats."
            confidence = early if request.entry_count < 4 else ready
            pattern_name = f"This week’s observation: {top_token}"
            pattern_summary = f"{confidence} “{top_token}” appears first; watch which situations bring it back."
            friction_name = "A possible drain this week"
            friction_summary = f"For now, watch the load around “{top_token}.” Signals are denser on {peak_day}, but this is not a conclusion."
            action = f"This week, when “{top_token}” appears again, add one sentence about the situation."
            snapshot_name = "Make the repeating Signal visible"
            snapshot_summary = f"If “{top_token}” returns, record it in a structured way before deciding whether to adjust anything."
            insight = f"{confidence} Watch “{top_token}” first; Signals are denser on {peak_day}."
            behavior_fallback = "Observation alone can help"
            friction_fallback = "Tasks pile up and starting becomes harder"

        patterns = [
            WeeklyInsightItem(
                name=pattern_name,
                summary=pattern_summary,
                illustration_hint=self._weekly_illustration_hint(
                    text,
                    fallback=behavior_fallback,
                    language=language,
                ),
                trigger=self._weekly_pattern_trigger(
                    day_counts=request.day_counts,
                    top_token=top_token,
                    language=language,
                ),
            )
        ]
        frictions = [
            WeeklyInsightItem(
                name=friction_name,
                summary=friction_summary,
                illustration_hint=self._weekly_illustration_hint(
                    " ".join([top_token, peak_day, *contents]),
                    fallback=friction_fallback,
                    language=language,
                ),
            )
        ]
        return WeeklyGenerateResponse(
            week_start=request.week_start,
            week_end=request.week_end,
            status="ready",
            key_insight=insight,
            patterns=patterns,
            frictions=frictions,
            best_action=action,
            opportunity_snapshot=OpportunitySnapshotSchema(
                name=snapshot_name,
                summary=snapshot_summary,
                illustration_hint=behavior_fallback,
            ),
            feedback_submitted=False,
        )

    def _weekly_illustration_hint(
        self,
        text: str,
        *,
        fallback: str,
        language: str = "zh-Hans",
    ) -> str:
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
                if language == "zh-Hans":
                    return hint
                localized = {
                    "zh-Hant": {
                        "任務堆積，開始變困難": "任務堆積，開始變得困難",
                        "會議密集，注意力被切碎": "會議密集，注意力被切碎",
                        "臨時變化打斷原本節奏": "臨時變化打斷原本節奏",
                        "休息時間被任務擠掉": "休息時間被任務擠掉",
                    },
                    "ja": {
                        "任务堆积，开始变困难": "予定が重なり、始めにくくなる",
                        "会议密集，注意力被切碎": "会議が続き、集中が細切れになる",
                        "临时变化打断原本节奏": "急な変更で流れが中断される",
                        "休息时间被任务挤掉": "予定に押されて休む時間が減る",
                    },
                    "en": {
                        "任务堆积，开始变困难": "Tasks pile up and starting becomes harder",
                        "会议密集，注意力被切碎": "Dense meetings fragment attention",
                        "临时变化打断原本节奏": "Unexpected changes interrupt the original rhythm",
                        "休息时间被任务挤掉": "Tasks crowd out time to rest",
                    },
                }
                return localized.get(language, {}).get(hint, fallback)
        return fallback

    def generate_light_dialog(self, request) -> LightDialogResponse:
        capture_content = request.capture_content.strip()
        user_message = request.user_message.strip()
        if not capture_content or not user_message:
            raise ValueError("capture_content and user_message are required")

        language = self._dialog_language(
            requested=request.language,
            user_message=user_message,
            capture_content=capture_content,
        )
        history_text = " ".join(turn.text for turn in request.history)
        safety_text = " ".join(
            part for part in (capture_content, history_text, user_message) if part
        )
        if self._is_immediate_safety_risk(safety_text):
            return LightDialogResponse(
                reply=self._dialog_safety_reply(language),
                suggested_prompts=[],
            )

        # The Flutter chat surface historically included the just-submitted user
        # turn in `history` as well as `user_message`.  Treat that as one turn so
        # the first response does not accidentally become a generic continuation.
        history = list(request.history)
        if (
            history
            and history[-1].role == "user"
            and history[-1].text.strip() == user_message
        ):
            history = history[:-1]

        recent_assistant_texts = [
            turn.text.strip()
            for turn in history
            if turn.role == "assistant" and turn.text.strip()
        ]
        capture_acknowledgement = (request.capture_acknowledgement or "").strip()
        if capture_acknowledgement:
            recent_assistant_texts.append(capture_acknowledgement)

        source_analysis = self._analyze_capture(capture_content)
        source_emotion = source_analysis["emotion"]
        source_axis = self.classification_service._detect_axis(capture_content)
        turn_analysis = self._analyze_capture(user_message)
        turn_emotion = turn_analysis["emotion"]
        turn_axis = self.classification_service._detect_axis(user_message)
        turn_acknowledgement = self._dialog_source_acknowledgement(
            capture_content=user_message,
            language=language,
            axis=turn_axis,
            emotion=turn_emotion,
            recent_assistant_texts=recent_assistant_texts,
        )
        intent = self._dialog_turn_intent(user_message)
        if intent == "repair":
            answer = self._dialog_repair_reply(
                language=language,
                source_axis=source_axis,
            )
            response_style = "gentle"
            return LightDialogResponse(
                reply=self._style_dialog_reply(
                    answer,
                    response_style,
                    language,
                ),
                suggested_prompts=[],
            )
        light_followup = self._dialog_light_followup(
            language=language,
            intent=intent,
            axis=source_axis,
            emotion=source_emotion,
        )
        response_style = request.response_style or 'gentle'
        if turn_emotion == "negative":
            response_style = "gentle"
        answer = f"{turn_acknowledgement} {light_followup}".strip()
        return LightDialogResponse(
            reply=self._style_dialog_reply(answer, response_style, language),
            suggested_prompts=[],
        )

    def _dialog_language(
        self,
        *,
        requested: str | None,
        user_message: str,
        capture_content: str,
    ) -> str:
        normalized = (requested or "").strip().lower().replace("_", "-")
        if normalized.startswith("ja"):
            return "ja"
        if normalized.startswith("en"):
            return "en"
        if normalized in {"zh-hant", "zh-tw", "zh-hk", "zh-mo"}:
            return "zh-Hant"
        if normalized.startswith("zh"):
            return "zh-Hans"

        combined = f"{user_message} {capture_content}"
        if any(char in combined for char in "這裡麼為會覺讓與還說體來時個後點願該辦實復"):
            return "zh-Hant"
        detected = self.classification_service._detect_language(
            user_message or capture_content
        )
        return {"ja": "ja", "en": "en"}.get(detected, "zh-Hans")

    def _dialog_source_acknowledgement(
        self,
        *,
        capture_content: str,
        language: str,
        axis: str,
        emotion: str,
        recent_assistant_texts: list[str],
    ) -> str:
        detected = self.classification_service._detect_language(capture_content)
        expected = {"ja": "ja", "en": "en"}.get(language, "zh")
        if detected != expected:
            return self._localized_dialog_source_ack(language, axis, emotion)

        acknowledgement = self.classification_service.generate_acknowledgement(
            content=capture_content,
            recent_assistant_texts=recent_assistant_texts,
            language=language,
        ).strip()
        if language == "zh-Hant":
            return self._to_traditional_chinese(acknowledgement)
        return acknowledgement

    def _localized_dialog_source_ack(
        self,
        language: str,
        axis: str,
        emotion: str,
    ) -> str:
        keys = {
            "unfairness": "unfairness",
            "interruption": "interruption",
            "repetition": "repetition",
            "confirmation": "confirmation",
            "overload": "overload",
            "no_break": "no_break",
            "fatigue": "fatigue",
            "confusion": "confusion",
            "pleasant_moment": "positive",
        }
        key = keys.get(axis, emotion if emotion in {"positive", "negative", "mixed"} else "general")
        messages = {
            "zh-Hans": {
                "unfairness": "你写下了本不该由你承担的事情落到了你这里。",
                "interruption": "你写下了节奏一直被打断和切换。",
                "repetition": "你写下了又要重来一遍。",
                "confirmation": "你写下了反复确认和对齐。",
                "overload": "一下子有这么多事压过来，确实很容易让人喘不过气。",
                "no_break": "一整段时间都没能停下来，听起来连喘口气的余地都没有。",
                "fatigue": "听起来你现在真的很累，这份疲惫值得被好好看见。",
                "confusion": "现在不知道从哪里开始，这种卡住的感觉确实不好受。",
                "positive": "听得出来，今天这份开心很真切，也值得好好留住。",
                "negative": "听起来这一刻真的不好受，这份感受值得被认真对待。",
                "mixed": "你写下了几种交在一起的感受。",
                "general": "我听见你刚才说的这件事了，先不替你的感受下结论。",
            },
            "zh-Hant": {
                "unfairness": "你寫下了本不該由你承擔的事情落到了你這裡。",
                "interruption": "你寫下了節奏一直被打斷和切換。",
                "repetition": "你寫下了又要重來一遍。",
                "confirmation": "你寫下了反覆確認和對齊。",
                "overload": "一下子有這麼多事壓過來，確實很容易讓人喘不過氣。",
                "no_break": "一整段時間都沒能停下來，聽起來連喘口氣的餘地都沒有。",
                "fatigue": "聽起來你現在真的很累，這份疲憊值得被好好看見。",
                "confusion": "現在不知道從哪裡開始，這種卡住的感覺確實不好受。",
                "positive": "聽得出來，今天這份開心很真切，也值得好好留住。",
                "negative": "聽起來這一刻真的不好受，這份感受值得被認真對待。",
                "mixed": "你寫下了幾種交在一起的感受。",
                "general": "我聽見你剛才說的這件事了，先不替你的感受下結論。",
            },
            "ja": {
                "unfairness": "本来あなたが引き受けるはずではないことが来た、と書いてくれましたね。",
                "interruption": "流れが何度も中断され、切り替えが続いたと書いてくれましたね。",
                "repetition": "またやり直すことになった、と書いてくれましたね。",
                "confirmation": "確認や調整を何度も繰り返した、と書いてくれましたね。",
                "overload": "いろいろなことが一度に重なると、息をつく余裕もなくなるほど苦しくなりますよね。",
                "no_break": "ずっと立ち止まる余裕がなかったのですね。息をつく間もないのは本当に消耗しますよね。",
                "fatigue": "今、本当に疲れているのですね。その疲れはきちんと受け止めたいです。",
                "confusion": "今はどこから手をつければよいかわからず、立ち止まってしまう感覚なのですね。",
                "positive": "今日の嬉しさがまっすぐ伝わってきます。大切に残しておきたい瞬間ですね。",
                "negative": "今この瞬間が本当につらいのですね。その気持ちを軽く扱わずに受け止めます。",
                "mixed": "いくつかの気持ちが混ざっていることを、そのまま残します。",
                "general": "今話してくれたことを聞いています。こちらで意味を決めつけずに受け止めます。",
            },
            "en": {
                "unfairness": "You wrote that something you should not have had to carry landed on you.",
                "interruption": "You wrote that your flow kept being interrupted and switched.",
                "repetition": "You wrote that you had to do it over again.",
                "confirmation": "You wrote that you had to check and align things repeatedly.",
                "overload": "Having so many things land at once can feel genuinely overwhelming.",
                "no_break": "Going that long without a chance to stop can leave no room even to catch your breath.",
                "fatigue": "You sound genuinely tired, and that exhaustion deserves to be noticed.",
                "confusion": "Not knowing where to begin can leave you feeling genuinely stuck.",
                "positive": "The happiness in this moment comes through clearly, and it is worth holding onto.",
                "negative": "This moment sounds genuinely hard, and I do not want to brush that feeling aside.",
                "mixed": "You wrote down several mixed feelings.",
                "general": "I hear what you just said without deciding what it means for you.",
            },
        }
        return messages[language][key]

    def _dialog_turn_intent(self, user_message: str) -> str:
        normalized = user_message.strip().lower()
        if any(token in normalized for token in [
            "太无情", "太無情", "太冷", "冷漠", "没接住", "沒接住",
            "没理解", "沒理解", "像机器人", "像機器人", "敷衍",
            "冷たい", "よそよそしい", "分かってくれない", "わかってくれない",
            "heartless", "uncaring", "too cold", "felt cold",
            "did not hear me", "didn't hear me", "did not understand me",
            "didn't understand me", "like a robot",
        ]):
            return "repair"
        # An explicit request for a way forward wins over a simultaneous
        # "why".  That preserves the user's confirmed exception: default L1
        # chat only acknowledges, while an explicit advice request may receive
        # one light, reversible response.
        if any(token in normalized for token in [
            "怎么办", "怎麼辦", "怎么做", "怎麼做", "该怎么", "該怎麼", "如何",
            "该做什么", "該做什麼", "what should", "what can i do", "what do i do",
            "how should", "how do i", "どうしたら", "どうすれば", "何をすれば", "どうすべき",
        ]):
            return "advice"
        if any(token in normalized for token in [
            "为什么", "為什麼", "为何", "為何", "why", "なぜ", "どうして", "なんで",
        ]):
            return "why"
        if any(token in normalized for token in [
            "其实", "其實", "actually", "実は", "本当は", "本當是",
        ]):
            return "clarify"
        return "share"

    def _dialog_repair_reply(self, *, language: str, source_axis: str) -> str:
        if source_axis == "overload":
            return {
                "zh-Hans": "你说得对，刚才那句没有接住你一下子被很多事压着的感受。",
                "zh-Hant": "你說得對，剛才那句沒有接住你一下子被很多事壓著的感受。",
                "ja": "その通りです。さっきの言葉は、いろいろなことに押されている苦しさを受け止められていませんでした。",
                "en": "You are right; my last reply did not meet the feeling of having so many things pressing on you.",
            }[language]
        return {
            "zh-Hans": "你说得对，刚才那句太像在处理一条记录，没有接住你当时的感受。",
            "zh-Hant": "你說得對，剛才那句太像在處理一條記錄，沒有接住你當時的感受。",
            "ja": "その通りです。さっきの言葉は記録を処理するようで、あなたの気持ちを受け止められていませんでした。",
            "en": "You are right; my last reply sounded like it was processing a record instead of meeting what you were feeling.",
        }[language]

    def _dialog_light_followup(
        self,
        *,
        language: str,
        intent: str,
        axis: str,
        emotion: str,
    ) -> str:
        if intent == "why":
            return {
                "zh-Hans": "只凭这一条还不能替你判断原因，但你正在困惑为什么会这样，我接到了。",
                "zh-Hant": "只憑這一條還不能替你判斷原因，但你正在困惑為什麼會這樣，我接到了。",
                "ja": "この一件だけで理由を決めることはできませんが、なぜこうなるのか戸惑っていることは受け取りました。",
                "en": "This one entry is not enough to decide the reason, but I hear that you are wondering why this keeps feeling this way.",
            }[language]
        if intent == "clarify":
            return ""
        if intent == "advice":
            advice_key = axis if axis in {
                "unfairness", "interruption", "repetition", "confirmation",
                "overload", "confusion",
            } else ("positive" if emotion == "positive" else "general")
            advice = {
                "zh-Hans": {
                    "unfairness": "如果愿意，先说清哪一部分其实不该由你承担，不必马上解决整件事。",
                    "interruption": "如果愿意，下一次切换前只停一下，确认手上的事做到哪里就够了。",
                    "repetition": "如果愿意，先分清这次最耗你的是重做本身，还是再次被打断的感觉。",
                    "confirmation": "如果愿意，先停在最需要反复确认的那一步，不必一次理清全部。",
                    "overload": "如果愿意，先只说出此刻最压着你的那一件，不必马上处理。",
                    "confusion": "现在不用找完整答案，只选一个最想先稳住的部分就够了。",
                    "positive": "如果愿意，可以先留意这个片刻里哪一点最让你松下来。",
                    "general": "如果愿意，先找一个现在负担最小、能让你稍微稳一点的起点就够了。",
                },
                "zh-Hant": {
                    "unfairness": "如果願意，先說清哪一部分其實不該由你承擔，不必馬上解決整件事。",
                    "interruption": "如果願意，下一次切換前只停一下，確認手上的事做到哪裡就夠了。",
                    "repetition": "如果願意，先分清這次最耗你的是重做本身，還是再次被打斷的感覺。",
                    "confirmation": "如果願意，先停在最需要反覆確認的那一步，不必一次理清全部。",
                    "overload": "如果願意，先只說出此刻最壓著你的那一件，不必馬上處理。",
                    "confusion": "現在不用找完整答案，只選一個最想先穩住的部分就夠了。",
                    "positive": "如果願意，可以先留意這個片刻裡哪一點最讓你鬆下來。",
                    "general": "如果願意，先找一個現在負擔最小、能讓你稍微穩一點的起點就夠了。",
                },
                "ja": {
                    "unfairness": "よければ、まず本来あなたが背負わなくてよい部分だけ言葉にして、全部を今すぐ解決しなくて大丈夫です。",
                    "interruption": "よければ、次に切り替える直前に一度だけ止まり、今の作業がどこまで進んだか確かめるだけで十分です。",
                    "repetition": "よければ、やり直し自体と再び流れを切られることのどちらがより消耗するかだけ見てみましょう。",
                    "confirmation": "よければ、いちばん確認が繰り返される一か所だけに目を向け、全部を一度に整理しなくて大丈夫です。",
                    "overload": "よければ、今いちばん重くのしかかっている一つだけを言葉にして、すぐ処理しなくても大丈夫です。",
                    "confusion": "今は完全な答えを探さず、まず少し安定させたい部分を一つ選ぶだけで十分です。",
                    "positive": "よければ、この瞬間の何がいちばん力を抜かせてくれたかだけ見てみましょう。",
                    "general": "よければ、今いちばん負担が小さく、少し落ち着ける入口を一つ探すだけで十分です。",
                },
                "en": {
                    "unfairness": "If you want, name just the part that should not have been yours to carry without solving the whole situation now.",
                    "interruption": "If you want, pause once before the next switch and simply note where you are leaving the current task.",
                    "repetition": "If you want, notice whether redoing it or having your flow broken again is the more draining part.",
                    "confirmation": "If you want, stay with the one step that needs the most repeated checking without sorting out everything at once.",
                    "overload": "If you want, name only the one thing pressing on you most right now without handling it immediately.",
                    "confusion": "You do not need a complete answer now; choosing one part you most want to steady is enough.",
                    "positive": "If you want, notice what in this moment helped you loosen up the most.",
                    "general": "If you want, finding the lowest-pressure place to begin and feel a little steadier is enough.",
                },
            }
            return advice[language][advice_key]
        return ""

    def _dialog_safety_reply(self, language: str) -> str:
        return {
            "zh-Hans": self._immediate_safety_reply(),
            "zh-Hant": (
                "我很在意你剛才這句話。若你現在可能馬上傷害自己或他人，"
                "請先離開危險物品並聯絡當地緊急服務，或立刻聯絡一個能到你身邊的可信任的人。"
                "如果可以，只回覆我：你現在是否處於立即危險中？"
            ),
            "ja": (
                "今の言葉をとても心配しています。今すぐ自分や誰かを傷つける可能性があるなら、"
                "危険な物から離れ、地域の緊急窓口か、すぐそばに来られる信頼できる人へ連絡してください。"
                "できれば、今すぐの危険があるかだけ教えてください。"
            ),
            "en": (
                "I am very concerned about what you just said. If you may hurt yourself or someone else now, "
                "move away from anything dangerous and contact local emergency services or a trusted person who can reach you. "
                "If you can, tell me only whether you are in immediate danger right now."
            ),
        }[language]

    def _style_dialog_reply(
        self,
        text: str,
        response_style: str,
        language: str,
    ) -> str:
        text = (text or "").strip()
        if not text or response_style == "gentle":
            return text
        prefixes = {
            "direct": {
                "zh-Hans": "重点是：",
                "zh-Hant": "重點是：",
                "ja": "要点は、",
                "en": "The main point: ",
            },
            "clear": {
                "zh-Hans": "更具体一点，",
                "zh-Hant": "更具體一點，",
                "ja": "もう少し具体的に言うと、",
                "en": "More specifically, ",
            },
        }
        prefix = prefixes.get(response_style, {}).get(language, "")
        return f"{prefix}{text}" if prefix and not text.startswith(prefix) else text

    def _to_traditional_chinese(self, text: str) -> str:
        # This path only converts the bounded L1 acknowledgement catalog above;
        # it is intentionally not a general-purpose user-content transformer.
        table = str.maketrans({
            "这": "這", "里": "裡", "让": "讓", "难": "難", "责": "責",
            "务": "務", "压": "壓", "烦": "煩", "错": "錯", "变": "變",
            "实": "實", "节": "節", "总": "總", "断": "斷", "稳": "穩",
            "个": "個", "复": "復", "觉": "覺", "来": "來", "会": "會",
            "认": "認", "顺": "順", "对": "對", "协": "協", "轻": "輕",
            "说": "說", "够": "夠", "现": "現", "观": "觀", "发": "發",
            "过": "過", "种": "種", "为": "為", "应": "應", "担": "擔",
            "并": "並", "没": "沒", "开": "開", "带": "帶", "与": "與",
        })
        return text.translate(table)

    def _is_immediate_safety_risk(self, text: str) -> bool:
        return self.classification_service.is_immediate_safety_risk(text)

    def _immediate_safety_reply(self, language: str = "zh-Hans") -> str:
        return self.classification_service.immediate_safety_acknowledgement(
            language
        )

    def _capture_safety_copy(self, language: str) -> dict[str, str]:
        return {
            "zh-Hans": {
                "observation": "先确认你现在是否处于立即危险中。",
                "try_next": "请先联系当地紧急服务，或一个能马上到你身边的可信任的人。",
            },
            "zh-Hant": {
                "observation": "先確認你現在是否處於立即危險中。",
                "try_next": "請先聯絡當地緊急服務，或一個能馬上到你身邊的可信任的人。",
            },
            "ja": {
                "observation": "まず、今すぐ危険な状態にあるかを確認してください。",
                "try_next": "地域の緊急窓口か、すぐそばに来られる信頼できる人へ連絡してください。",
            },
            "en": {
                "observation": "First, confirm whether you are in immediate danger.",
                "try_next": "Contact local emergency services or a trusted person who can be with you now.",
            },
        }[language]

    def generate_deep_weekly(self, request: DeepWeeklyRequest) -> DeepWeeklyResponse:
        language = self._request_language(request.language)
        pattern_name = self._pick_name(request.patterns, fallback="这周反复回来的主题")
        friction_name = self._pick_name(request.frictions, fallback="这周最稳定的消耗点")
        if language != "zh-Hans":
            fallback_names = {
                "zh-Hant": ("這週反覆出現的主題", "這週最穩定的消耗點"),
                "ja": ("今週繰り返し現れたテーマ", "今週続いた主な負担"),
                "en": ("this week’s recurring theme", "this week’s most consistent drain"),
            }[language]
            pattern_name = self._pick_name(request.patterns, fallback=fallback_names[0])
            friction_name = self._pick_name(request.frictions, fallback=fallback_names[1])
            return self._generate_localized_deep_weekly(
                request=request,
                language=language,
                pattern_name=pattern_name,
                friction_name=friction_name,
            )
        illustration_hint = self._pick_illustration_hint(
            request.patterns
        ) or self._pick_illustration_hint(request.frictions)
        key_insight = (request.key_insight or "").strip() or f"这周的记录在“{pattern_name}”附近逐渐聚起来。"

        peak_day = "这周中段"
        low_day = "这周某个低点"
        rebound_phrase = "后半段还没有足够 Signal 说明已经回弹"
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

        relationship_summary = (
            f"“{pattern_name}”与“{friction_name}”在本周同一范围内反复同时出现，"
            "值得继续看它们怎样牵动节奏。"
        )
        summary = f"{key_insight} 深度分析看到：{relationship_summary}"
        root_tension = (
            f"内在拉扯：想让“{pattern_name}”推进时，"
            f"“{friction_name}”也会反复出现。"
        )
        timing_summary = f"{peak_day} 的 Signal 更密，{low_day} 更像状态低点；{rebound_phrase}。"
        hidden_pattern = timing_summary
        next_question = (
            f"“{friction_name}”再次出现时，它发生在“{pattern_name}”的开始、推进还是收尾？"
        )
        next_focus = f"下周只验证一个问题：{next_question}"
        scope_note = (
            "这份深度分析只说明本周 Signal 中反复同时出现的关系，"
            "用于确定下周观察点，不代表因果、人格判断或长期结论。"
        )
        risk_note = scope_note

        if request.completed_attempt_day_count > 0:
            impact_label = f"已有 {request.completed_attempt_day_count} 个完成日"
        elif request.recorded_attempt_day_count > 0:
            impact_label = f"已有 {request.recorded_attempt_day_count} 个反馈日"
        elif request.attempt_count > 0:
            impact_label = f"已参与 {request.attempt_count} 项尝试"
        else:
            impact_label = "尝试反馈仍在形成"
        if request.dominant_feedback_pattern:
            impact_label = request.dominant_feedback_pattern.strip() or impact_label
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
            pattern_label=pattern_name,
            friction_label=friction_name,
            impact_label=impact_label,
            relationship_summary=relationship_summary,
            timing_summary=timing_summary,
            next_question=next_question,
            illustration_hint=illustration_hint,
            source_signal_card_ids=request.source_signal_card_ids,
            scope_note=scope_note,
        )

    def _generate_localized_deep_weekly(
        self,
        *,
        request: DeepWeeklyRequest,
        language: str,
        pattern_name: str,
        friction_name: str,
    ) -> DeepWeeklyResponse:
        illustration_hint = self._pick_illustration_hint(
            request.patterns
        ) or self._pick_illustration_hint(request.frictions)
        peak_day = {
            "zh-Hant": "這週中段",
            "ja": "週の半ば",
            "en": "the middle of the week",
        }[language]
        low_day = {
            "zh-Hant": "這週某個低點",
            "ja": "今週のある低い日",
            "en": "a lower point this week",
        }[language]
        rebounded = False
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
            rebounded = last.get("mood_score", 0) > low.get("mood_score", 0)

        key_insight = (request.key_insight or "").strip()
        if not key_insight:
            key_insight = {
                "zh-Hant": f"這週的 Signal 逐漸聚集在「{pattern_name}」附近。",
                "ja": f"今週の Signal は「{pattern_name}」の周辺に集まり始めています。",
                "en": f"This week’s Signals are beginning to gather around “{pattern_name}.”",
            }[language]
        relationship = {
            "zh-Hant": f"「{pattern_name}」與「{friction_name}」在本週同一範圍內反覆同時出現，值得繼續看它們如何牽動節奏。",
            "ja": f"「{pattern_name}」と「{friction_name}」は今週同じ範囲で繰り返し現れました。両者が流れにどう関わるかを引き続き見ます。",
            "en": f"“{pattern_name}” and “{friction_name}” repeatedly appeared within the same range this week. Keep watching how they shape the rhythm.",
        }[language]
        root_tension = {
            "zh-Hant": f"內在拉扯：想推進「{pattern_name}」時，「{friction_name}」也會反覆出現。",
            "ja": f"内側の揺れ：「{pattern_name}」を進めようとすると、「{friction_name}」も繰り返し現れます。",
            "en": f"Internal tension: as “{pattern_name}” moves forward, “{friction_name}” also keeps returning.",
        }[language]
        timing = {
            "zh-Hant": f"{peak_day} 的 Signal 較密，{low_day} 較像狀態低點；" + (
                "後半段有一點回收，顯示狀態曾被拉回來一些。"
                if rebounded else
                "後半段還沒有足夠 Signal 顯示已經回彈。"
            ),
            "ja": f"{peak_day} は Signal が多く、{low_day} は状態の低い点に見えます。" + (
                "後半には少し持ち直した動きがあります。"
                if rebounded else
                "後半に持ち直したと判断できるほどの Signal はまだありません。"
            ),
            "en": f"Signals are denser on {peak_day}, while {low_day} looks like a lower point. " + (
                "The later part shows some recovery."
                if rebounded else
                "There are not yet enough later Signals to show a rebound."
            ),
        }[language]
        question = {
            "zh-Hant": f"「{friction_name}」再次出現時，它發生在「{pattern_name}」的開始、推進，還是收尾？",
            "ja": f"「{friction_name}」が再び現れるとき、それは「{pattern_name}」の開始、進行中、終わりのどこですか？",
            "en": f"When “{friction_name}” appears again, is it at the beginning, middle, or end of “{pattern_name}”?",
        }[language]
        scope = {
            "zh-Hant": "這份深度分析只說明本週 Signal 中反覆同時出現的關係，用於確定下週觀察點，不代表因果、人格判斷或長期結論。",
            "ja": "この深度分析が示すのは、今週の Signal で繰り返し同時に現れた関係だけです。来週の観察点を決めるためのもので、因果関係、人格判断、長期的な結論ではありません。",
            "en": "This deep analysis only describes relationships that repeatedly co-occurred in this week’s Signals. It helps set next week’s observation point and does not establish causation, personality, or a long-term conclusion.",
        }[language]
        if request.completed_attempt_day_count > 0:
            impact = {
                "zh-Hant": f"已有 {request.completed_attempt_day_count} 個完成日",
                "ja": f"完了日 {request.completed_attempt_day_count} 日",
                "en": f"{request.completed_attempt_day_count} completed days",
            }[language]
        elif request.recorded_attempt_day_count > 0:
            impact = {
                "zh-Hant": f"已有 {request.recorded_attempt_day_count} 個回饋日",
                "ja": f"記録日 {request.recorded_attempt_day_count} 日",
                "en": f"{request.recorded_attempt_day_count} feedback days",
            }[language]
        elif request.attempt_count > 0:
            impact = {
                "zh-Hant": f"已參與 {request.attempt_count} 項嘗試",
                "ja": f"{request.attempt_count} 件の試みを実施",
                "en": f"{request.attempt_count} attempts joined",
            }[language]
        else:
            impact = {
                "zh-Hant": "嘗試回饋仍在形成",
                "ja": "試行の反応はまだ形成中です",
                "en": "Attempt feedback is still forming",
            }[language]
        if request.dominant_feedback_pattern:
            impact = request.dominant_feedback_pattern.strip() or impact
        summary_prefix = {
            "zh-Hant": "深度分析看到：",
            "ja": "深度分析で見えること：",
            "en": "Deep analysis: ",
        }[language]
        next_focus = {
            "zh-Hant": f"下週只驗證一個問題：{question}",
            "ja": f"来週は一つの問いだけを確かめます：{question}",
            "en": f"Test one question next week: {question}",
        }[language]
        nodes = {
            "zh-Hant": [
                f"反覆主題：{pattern_name}",
                f"主要摩擦：{friction_name}",
                f"Signal 密集點：{peak_day}",
                f"走勢低點：{low_day}",
            ],
            "ja": [
                f"繰り返すテーマ：{pattern_name}",
                f"主な負担：{friction_name}",
                f"Signal が多い日：{peak_day}",
                f"状態の低い日：{low_day}",
            ],
            "en": [
                f"Recurring theme: {pattern_name}",
                f"Main friction: {friction_name}",
                f"Signal peak: {peak_day}",
                f"Lower point: {low_day}",
            ],
        }[language]
        return DeepWeeklyResponse(
            summary=f"{key_insight} {summary_prefix}{relationship}",
            root_tension=root_tension,
            hidden_pattern=timing,
            next_focus=next_focus,
            risk_note=scope,
            key_nodes=nodes,
            pattern_label=pattern_name,
            friction_label=friction_name,
            impact_label=impact,
            relationship_summary=relationship,
            timing_summary=timing,
            next_question=question,
            illustration_hint=illustration_hint,
            source_signal_card_ids=request.source_signal_card_ids,
            scope_note=scope,
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

    def _pick_illustration_hint(self, items) -> str | None:
        if not items:
            return None
        first = items[0]
        if isinstance(first, dict):
            value = str(first.get("illustration_hint") or "").strip()
            return value or None
        value = str(getattr(first, "illustration_hint", "") or "").strip()
        return value or None

    def generate_journey_summary(
        self,
        request: JourneyGenerateRequest,
    ) -> JourneyGenerateResponse:
        contents = [entry.content.strip() for entry in request.entries if entry.content and entry.content.strip()]
        language = self._request_language(request.language, request.entries)
        top_token = self._evidence_topic(
            contents=contents,
            top_tokens=request.top_tokens,
            language=language,
        )
        total_days = max(request.total_days, 1)
        if language == "zh-Hans":
            confidence = "还只是早期生活轨迹" if request.entry_count < 6 else "已经开始有长期线索"
            copy = {
                "pattern_name": "正在形成的生活路径",
                "pattern_summary": f"{confidence}：目前最清楚的是“{top_token}”。先看它是偶尔出现，还是慢慢变成重复结构。",
                "friction_name": "可能的长期消耗",
                "friction_summary": f"如果“{top_token}”继续出现，它可能是后面要回看的消耗来源；现在先保持轻观察。",
                "desire_name": "还在浮现的方向",
                "desire_summary": f"记录已经跨越 {total_days} 天，先从真实记录里看哪些事让你想恢复、期待或离开消耗。",
                "experiment_name": "尝试反馈",
                "experiment_summary": "后续尝试反馈会和这些记录放在一起看：有帮助、偏难或跳过都只是反馈，不是失败。",
            }
        else:
            copy = {
                "zh-Hant": {
                    "pattern_name": "正在形成的生活路徑",
                    "pattern_summary": f"{'目前仍是早期生活軌跡' if request.entry_count < 6 else '已經開始出現長期線索'}：現在最清楚的是「{top_token}」。先看它是偶爾出現，還是逐漸成為反覆結構。",
                    "friction_name": "可能的長期消耗",
                    "friction_summary": f"如果「{top_token}」持續出現，它可能是之後值得回看的消耗來源；現在先保持輕量觀察。",
                    "desire_name": "還在浮現的方向",
                    "desire_summary": f"記錄已跨越 {total_days} 天，先從真實記錄中看哪些事讓你想恢復、期待，或離開消耗。",
                    "experiment_name": "嘗試回饋",
                    "experiment_summary": "之後的嘗試回饋會和這些記錄放在一起看：有幫助、偏難或跳過都只是回饋，不是失敗。",
                },
                "ja": {
                    "pattern_name": "形になり始めた生活の道筋",
                    "pattern_summary": f"{'まだ初期の生活軌跡です' if request.entry_count < 6 else '長期的な手がかりが見え始めています'}。今もっとも明確なのは「{top_token}」です。偶発的なものか、繰り返す構造になるかを見ていきます。",
                    "friction_name": "長く続く可能性のある負担",
                    "friction_summary": f"「{top_token}」が続くなら、あとで振り返るべき負担の源かもしれません。今は軽く観察します。",
                    "desire_name": "見え始めた方向",
                    "desire_summary": f"記録は {total_days} 日にわたっています。回復したいこと、楽しみなこと、離れたい負担を実際の記録から見ていきます。",
                    "experiment_name": "試したことへの反応",
                    "experiment_summary": "これからの反応は記録と合わせて見ます。役立った、難しかった、見送ったという結果は、失敗ではなく反応です。",
                },
                "en": {
                    "pattern_name": "An emerging life path",
                    "pattern_summary": f"{'This is still an early life trajectory' if request.entry_count < 6 else 'Longer-term clues are beginning to emerge'}. The clearest theme is “{top_token}.” Watch whether it is occasional or slowly becomes a recurring structure.",
                    "friction_name": "A possible longer-term drain",
                    "friction_summary": f"If “{top_token}” keeps returning, it may be a drain worth revisiting later. For now, observe it lightly.",
                    "desire_name": "A direction still emerging",
                    "desire_summary": f"The entries span {total_days} days. Use the actual records to see what makes you want to recover, look forward, or step away from a drain.",
                    "experiment_name": "Attempt feedback",
                    "experiment_summary": "Future attempt feedback will be read alongside these records. Helpful, difficult, or skipped are all feedback, not failure.",
                },
            }[language]

        return JourneyGenerateResponse(
            patterns=[
                WeeklyInsightItem(
                    name=copy["pattern_name"],
                    summary=copy["pattern_summary"],
                )
            ],
            frictions=[
                WeeklyInsightItem(
                    name=copy["friction_name"],
                    summary=copy["friction_summary"],
                )
            ],
            desires=[
                WeeklyInsightItem(
                    name=copy["desire_name"],
                    summary=copy["desire_summary"],
                )
            ],
            experiments=[
                WeeklyInsightItem(
                    name=copy["experiment_name"],
                    summary=copy["experiment_summary"],
                )
            ],
        )

    def generate_followup_question(self, payload: dict[str, Any]) -> dict[str, Any]:
        language = self.classification_service.normalize_language(payload.get("language"))
        copy = {
            "zh-Hans": ("你最烦的是找资料，还是整理结构？", ["找资料", "整理结构", "重新写", "先跳过"]),
            "zh-Hant": ("你最困擾的是找資料，還是整理結構？", ["找資料", "整理結構", "重新寫", "先跳過"]),
            "ja": ("いちばん負担なのは、情報を探すことですか、それとも構成を整えることですか？", ["情報を探す", "構成を整える", "書き直す", "今は見送る"]),
            "en": ("What is more frustrating: finding information or organizing the structure?", ["Find information", "Organize the structure", "Rewrite", "Skip for now"]),
        }[language]
        return {
            "question_type": "information_friction_detail",
            "question_text": copy[0],
            "options": [
                {"label": copy[1][0], "value": "find_info"},
                {"label": copy[1][1], "value": "organize_structure"},
                {"label": copy[1][2], "value": "rewrite"},
                {"label": copy[1][3], "value": "skip"},
            ],
        }

    def generate_monthly_summary(
        self,
        request: MonthlyGenerateRequest,
    ) -> MonthlyGenerateResponse:
        language = self._request_language(request.language, request.entries)
        contents = [
            entry.content.strip()
            for entry in request.entries
            if entry.content and entry.content.strip()
        ]
        if request.entry_count <= 0 or not contents:
            return MonthlyGenerateResponse(
                month_start=request.month_start,
                month_end=request.month_end,
                status="insufficient_data",
            )

        topic = self._evidence_topic(
            contents=contents,
            top_tokens=request.top_tokens,
            language=language,
        )
        total_days = max(request.total_days, 1)
        copy = {
            "zh-Hans": {
                "summary": f"这个月的记录主要围绕“{topic}”展开，共覆盖 {total_days} 个记录日。",
                "theme": f"“{topic}”在这个月反复出现。",
                "improving": "已经能从具体记录中看见一些恢复片段。",
                "unresolved": f"“{topic}”何时更容易出现，仍需要继续观察。",
                "watch": f"下个月继续留意“{topic}”出现时的场景与变化。",
                "bridge": "本月 Signal 已开始形成可回看的轨迹。",
            },
            "zh-Hant": {
                "summary": f"這個月的記錄主要圍繞「{topic}」展開，共涵蓋 {total_days} 個記錄日。",
                "theme": f"「{topic}」在這個月反覆出現。",
                "improving": "已經能從具體記錄中看見一些恢復片段。",
                "unresolved": f"「{topic}」何時更容易出現，仍需要繼續觀察。",
                "watch": f"下個月繼續留意「{topic}」出現時的場景與變化。",
                "bridge": "本月 Signal 已開始形成可回看的軌跡。",
            },
            "ja": {
                "summary": f"今月の記録は主に「{topic}」を中心に広がり、{total_days} 日分の記録があります。",
                "theme": f"「{topic}」が今月繰り返し現れました。",
                "improving": "具体的な記録から、少し回復した場面が見え始めています。",
                "unresolved": f"「{topic}」が起こりやすい条件は、まだ観察が必要です。",
                "watch": f"来月も「{topic}」が現れる場面と変化を見ていきます。",
                "bridge": "今月の Signal が、振り返れる軌跡になり始めています。",
            },
            "en": {
                "summary": f"This month’s entries mainly center on “{topic}” across {total_days} recorded days.",
                "theme": f"“{topic}” returned repeatedly this month.",
                "improving": "Specific entries are beginning to show moments of recovery.",
                "unresolved": f"The conditions that make “{topic}” more likely still need observation.",
                "watch": f"Next month, keep watching the situations and changes around “{topic}.”",
                "bridge": "This month’s Signals are beginning to form a trajectory you can revisit.",
            },
        }[language]
        return MonthlyGenerateResponse(
            month_start=request.month_start,
            month_end=request.month_end,
            status="ready",
            monthly_summary=copy["summary"],
            repeated_themes=[copy["theme"]],
            improving_signals=[copy["improving"]],
            unresolved_points=[copy["unresolved"]],
            next_month_watch=copy["watch"],
            weekly_bridges=[
                MonthlyBridgeWeekSchema(
                    label=f"{request.month_start}–{request.month_end}",
                    summary=copy["bridge"],
                )
            ],
        )

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
        language: str = "zh-Hans",
    ) -> dict[str, str]:
        recent_assistant_texts = recent_assistant_texts or []

        try:
            acknowledgement = self.classification_service.generate_acknowledgement(
                content=content,
                recent_assistant_texts=recent_assistant_texts,
                language=language,
            )
            if not isinstance(acknowledgement, str) or not acknowledgement.strip():
                raise ValueError("empty acknowledgement")
        except Exception:
            acknowledgement = self._fallback_acknowledgement(
                content=content,
                emotion=emotion,
                intensity=intensity,
                scene_tags=scene_tags,
                language=language,
            )

        observation = self._fallback_observation(
            content=content,
            emotion=emotion,
            scene_tags=scene_tags,
            language=language,
        )
        try_next = self._fallback_try_next(
            content=content,
            emotion=emotion,
            scene_tags=scene_tags,
            intent_tags=intent_tags,
            language=language,
        )
        topic = self.classification_service._topic_hint(content)
        if topic and language == "zh-Hans":
            observation = self._topic_observation(topic=topic)
            try_next = self._topic_try_next(topic=topic)

        return {
            "acknowledgement": self._style_text(
                acknowledgement.strip(),
                response_style,
                kind='acknowledgement',
                language=language,
            ),
            "observation": self._style_text(
                observation.strip(),
                response_style,
                kind='observation',
                language=language,
            ),
            "try_next": self._style_text(
                try_next.strip(),
                response_style,
                kind='suggestion',
                language=language,
            ),
        }

    def _topic_observation(self, *, topic: str) -> str:
        if topic == "cost":
            return "这条更像是成本提醒：当模型用量或智能助手的使用成本变得显眼，它会影响你对工具是否值得继续用的判断。"
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


    def _style_text(
        self,
        text: str,
        response_style: str,
        kind: str = 'reply',
        language: str = "zh-Hans",
    ) -> str:
        text = (text or '').strip()
        if not text:
            return text

        if response_style == 'direct':
            direct_prefix = {
                "zh-Hans": {
                    "acknowledgement": "先说重点：",
                    "suggestion": "下一步：",
                    "reply": "重点是：",
                },
                "zh-Hant": {
                    "acknowledgement": "先說重點：",
                    "suggestion": "下一步：",
                    "reply": "重點是：",
                },
                "ja": {
                    "acknowledgement": "要点を先に言うと、",
                    "suggestion": "次の一歩：",
                    "reply": "要点は、",
                },
                "en": {
                    "acknowledgement": "The main point: ",
                    "suggestion": "Next step: ",
                    "reply": "The main point: ",
                },
            }[language].get(kind, {
                "zh-Hans": "重点是：",
                "zh-Hant": "重點是：",
                "ja": "要点は、",
                "en": "The main point: ",
            }[language])
            return f"{direct_prefix}{text}" if not text.startswith(direct_prefix) else text

        if response_style == 'clear':
            clear_prefix = {
                "zh-Hans": {
                    "acknowledgement": "换句话说，",
                    "suggestion": "更清楚地说，",
                    "reply": "更具体一点，",
                },
                "zh-Hant": {
                    "acknowledgement": "換句話說，",
                    "suggestion": "更清楚地說，",
                    "reply": "更具體一點，",
                },
                "ja": {
                    "acknowledgement": "言い換えると、",
                    "suggestion": "もう少し明確に言うと、",
                    "reply": "もう少し具体的に言うと、",
                },
                "en": {
                    "acknowledgement": "In other words, ",
                    "suggestion": "More clearly, ",
                    "reply": "More specifically, ",
                },
            }[language].get(kind, {
                "zh-Hans": "更具体一点，",
                "zh-Hant": "更具體一點，",
                "ja": "もう少し具体的に言うと、",
                "en": "More specifically, ",
            }[language])
            return f"{clear_prefix}{text}" if not text.startswith(clear_prefix) else text

        return text

    def _fallback_acknowledgement(
        self,
        content: str,
        emotion: str,
        intensity: str,
        scene_tags: list[str],
        language: str = "zh-Hans",
    ) -> str:
        if language != "zh-Hans":
            key = emotion if emotion in {"positive", "mixed", "negative"} else "neutral"
            return {
                "zh-Hant": {
                    "positive": "聽得出來，這一刻的感覺很好，也值得好好留住。",
                    "mixed": "你寫下了幾種交在一起的感受，先原樣留在這裡。",
                    "negative": "聽起來這一刻真的不好受，這份感受值得被認真對待。",
                    "neutral": "這一條已經按你寫下的內容記下來了。",
                },
                "ja": {
                    "positive": "今のよい気持ちが伝わってきます。大切に残しておきたい瞬間ですね。",
                    "mixed": "いくつかの気持ちが混ざっていることを、そのまま残します。",
                    "negative": "今この瞬間が本当につらいのですね。その気持ちを軽く扱わずに受け止めます。",
                    "neutral": "書いてくれたことを、そのままここに残します。",
                },
                "en": {
                    "positive": "This moment sounds good, and it is worth holding onto.",
                    "mixed": "I am keeping these mixed feelings here as you described them.",
                    "negative": "This moment sounds genuinely hard, and that feeling deserves care.",
                    "neutral": "I am keeping what you wrote here as it is.",
                },
            }[language][key]
        if emotion == "positive":
            return "我听见你说这一刻感觉不错，先把它留在这里。"

        if emotion == "mixed":
            return "你写下了几种交在一起的感受，先原样留在这里。"

        if emotion == "negative":
            return "我听见你说这一刻很难受，这份感受先留在这里。"

        return "这一条已经按你写下的内容记下来了。"

    def _fallback_observation(
        self,
        content: str,
        emotion: str,
        scene_tags: list[str],
        language: str = "zh-Hans",
    ) -> str:
        if language != "zh-Hans":
            key = emotion if emotion in {"positive", "mixed", "negative"} else "neutral"
            return {
                "zh-Hant": {
                    "positive": "這條記錄顯示，一些具體的小好事確實能幫你補回狀態。",
                    "mixed": "這條裡最值得留意的是拉扯感：有消耗，也有一些片刻把你接住。",
                    "negative": "這條裡較明顯的線索是，某個具體場景正在持續消耗你。",
                    "neutral": "這更像是一條狀態線索，而不是一股很強的情緒。",
                },
                "ja": {
                    "positive": "この記録から、具体的な小さな出来事が気持ちを少し回復させていることが見えます。",
                    "mixed": "この記録では、消耗する感覚と少し持ち直す感覚の両方が大切な手がかりです。",
                    "negative": "この記録では、ある具体的な場面が継続して負担になっていることが見えます。",
                    "neutral": "これは強い感情というより、今の状態を示す手がかりに近そうです。",
                },
                "en": {
                    "positive": "This entry suggests that a specific small moment helped restore some energy.",
                    "mixed": "The tension between feeling drained and feeling restored is the clearest clue here.",
                    "negative": "The clearest clue is that a specific situation is steadily wearing you down.",
                    "neutral": "This reads more like a clue about your state than a strong emotion.",
                },
            }[language][key]
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
        language: str = "zh-Hans",
    ) -> str:
        if language != "zh-Hans":
            key = emotion if emotion in {"positive", "mixed", "negative"} else "neutral"
            return {
                "zh-Hant": {
                    "positive": "先記下是哪個具體片刻帶來了好一點的感覺，不用寫多。",
                    "mixed": "先不用總結整天，只記下是什麼讓你稍微緩了回來。",
                    "negative": "先記下最卡你的那個瞬間，其他暫時不用整理。",
                    "neutral": "先把這一條留著，看看它之後會不會再出現。",
                },
                "ja": {
                    "positive": "少しよい気持ちにつながった具体的な点だけ、短く残しておきましょう。",
                    "mixed": "一日全体をまとめず、少し持ち直せたきっかけだけ残してみてください。",
                    "negative": "いちばん引っかかった瞬間だけ残し、ほかは今すぐ整理しなくて大丈夫です。",
                    "neutral": "この記録をいったん残し、また同じことが起きるか見てみましょう。",
                },
                "en": {
                    "positive": "Note the specific detail that helped this moment feel better.",
                    "mixed": "For now, note only what helped you recover a little later.",
                    "negative": "Note the moment that felt most difficult; the rest can wait.",
                    "neutral": "Keep this entry and see whether the same clue returns.",
                },
            }[language][key]
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

    def _evidence_topic(
        self,
        *,
        contents: list[str],
        top_tokens: list[str],
        language: str = "zh-Hans",
    ) -> str:
        joined = " ".join(contents).lower()
        topic = self.classification_service._topic_hint(joined)
        labels = {
            "zh-Hans": {
                "cost": "模型用量成本",
                "horse_expectation": "骑马带来的期待和恢复",
                "tomorrow_uncertainty": "明天不可控与活在当下",
                "retirement_wish": "想离开工作消耗",
                "weather_good": "天气带来的轻一点的状态",
                "rest_wish": "想停下来休息",
                "money": "钱和成本压力",
            },
            "zh-Hant": {
                "cost": "模型用量成本",
                "horse_expectation": "騎馬帶來的期待和恢復",
                "tomorrow_uncertainty": "明天不可控與活在當下",
                "retirement_wish": "想離開工作消耗",
                "weather_good": "天氣帶來較輕鬆的狀態",
                "rest_wish": "想停下來休息",
                "money": "金錢和成本壓力",
            },
            "ja": {
                "cost": "モデル利用量の費用",
                "horse_expectation": "乗馬への期待と回復",
                "tomorrow_uncertainty": "明日の不確かさと今を生きること",
                "retirement_wish": "仕事の消耗から離れたい気持ち",
                "weather_good": "天気がもたらす軽やかな状態",
                "rest_wish": "立ち止まって休みたい気持ち",
                "money": "お金と費用の負担",
            },
            "en": {
                "cost": "model usage cost",
                "horse_expectation": "anticipation and recovery from riding",
                "tomorrow_uncertainty": "tomorrow’s uncertainty and staying present",
                "retirement_wish": "wanting to leave work-related drain",
                "weather_good": "a lighter state brought by the weather",
                "rest_wish": "wanting to stop and rest",
                "money": "money and cost pressure",
            },
        }
        if topic in labels[language]:
            return labels[language][topic]
        fallback = self._safe_top_token(top_tokens)
        if fallback == "最近的记录":
            return {
                "zh-Hans": fallback,
                "zh-Hant": "最近的記錄",
                "ja": "最近の記録",
                "en": "recent entries",
            }[language]
        return fallback

    def _weekly_pattern_trigger(
        self,
        *,
        day_counts: dict[str, int],
        top_token: str,
        language: str = "zh-Hans",
    ) -> str | None:
        supported_parts: list[str] = []
        if day_counts:
            peak_day, peak_count = max(day_counts.items(), key=lambda item: item[1])
            supported_parts.append({
                "zh-Hans": f"{peak_day} 记录了 {peak_count} 条 Signal，是本周较密集的日子",
                "zh-Hant": f"{peak_day} 記錄了 {peak_count} 條 Signal，是本週較密集的日子",
                "ja": f"{peak_day} は {peak_count} 件の Signal があり、今週では比較的多い日です",
                "en": f"{peak_day} has {peak_count} Signals, making it one of the denser days this week",
            }[language])
        if top_token and top_token != "最近的记录":
            supported_parts.append({
                "zh-Hans": f"本周 Signal 主题集中在“{top_token}”",
                "zh-Hant": f"本週 Signal 主題集中在「{top_token}」",
                "ja": f"今週の Signal は「{top_token}」に集まっています",
                "en": f"This week’s Signals cluster around “{top_token}”",
            }[language])
        separator = "；" if language in {"zh-Hans", "zh-Hant"} else "。"
        return separator.join(supported_parts) or None

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
