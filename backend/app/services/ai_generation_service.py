from __future__ import annotations

from collections import Counter
from typing import Any

from app.schemas.ai_schema import (
    CaptureReplyResponse,
    JourneyGenerateRequest,
    JourneyGenerateResponse,
    OpportunityExplanationResponse,
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

        analysis = self._analyze_capture(content)
        reply_bundle = self._build_reply_bundle(
            content=content,
            emotion=analysis["emotion"],
            intensity=analysis["intensity"],
            scene_tags=analysis["scene_tags"],
            intent_tags=analysis["intent_tags"],
            recent_assistant_texts=recent_assistant_texts,
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
            observation=observation,
            suggestion=suggestion,
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

        top_token = self._safe_top_token(request.top_tokens)
        peak_day = self._peak_day(request.day_counts)

        patterns = [
            WeeklyInsightItem(
                name="重复出现的主题",
                summary=f"这周几条记录开始往“{top_token}”上聚，说明它已经不只是一次性的瞬间。",
            ),
            WeeklyInsightItem(
                name=f"高频关键词：{top_token}",
                summary=f"从这周的本地统计看，“{top_token}”是目前最明显的长期线索之一。",
            ),
        ]

        frictions = [
            WeeklyInsightItem(
                name="本周的主要消耗",
                summary=f"这周更像是同类问题反复回来，而不是单次事件；其中 {peak_day} 的 signal 更集中。",
            ),
        ]

        best_action = f"这周先试一步：下次再出现“{top_token}”时，用一句话补记它发生在什么场景。"

        opportunity_snapshot = OpportunitySnapshotSchema(
            name="把重复信号固定下来",
            summary=f"如果“{top_token}”总是回来，它很适合先被结构化记录，再观察是否值得进一步模板化。",
        )

        return WeeklyGenerateResponse(
            week_start=request.week_start,
            week_end=request.week_end,
            status="ready",
            key_insight=f"这周的记录开始围绕“{top_token}”聚集，{peak_day} 的信号更密集。",
            patterns=patterns,
            frictions=frictions,
            best_action=best_action,
            opportunity_snapshot=opportunity_snapshot,
            feedback_submitted=False,
        )

    def generate_journey_summary(
        self,
        request: JourneyGenerateRequest,
    ) -> JourneyGenerateResponse:
        top_token = self._safe_top_token(request.top_tokens)
        total_days = max(request.total_days, 1)

        return JourneyGenerateResponse(
            patterns=[
                WeeklyInsightItem(
                    name="反复出现的主题",
                    summary=f"一路看下来，“{top_token}”开始不止一次地出现，说明它已经在慢慢形成长期模式。",
                )
            ],
            frictions=[
                WeeklyInsightItem(
                    name="持续性的摩擦",
                    summary="这段时间里，有些问题不是一次性的，而是在慢慢累积，开始形成稳定摩擦。",
                )
            ],
            desires=[
                WeeklyInsightItem(
                    name="还在浮现的方向",
                    summary=f"记录已经跨越 {total_days} 天，一些真正长期在意的方向正在慢慢浮现。",
                )
            ],
            experiments=[
                WeeklyInsightItem(
                    name="开始有帮助的东西",
                    summary="继续记录下去，会更容易看见什么做法不是偶然有效，而是在慢慢变得有帮助。",
                )
            ],
        )

    def generate_opportunity_explanation(self, payload: dict[str, Any]) -> OpportunityExplanationResponse:
        return OpportunityExplanationResponse(
            why_this_opportunity="过去几周里，你反复在开始任务前重新收集和整理资料，这让启动成本持续偏高。",
            evidence_summary=[
                "相关模式近几周持续出现",
                "主要摩擦集中在信息分散与启动困难",
                "你也表达过希望把这一步省掉",
            ],
            solution_fit_explanation="这类问题已经有比较清楚的输入和输出，适合先做 Copilot，而不是直接交给全自动 Agent。",
            next_step="先试一个最小版本：输入任务主题后，自动聚合相关资料并输出起步草稿。",
            user_facing_summary="这不是一个要你彻底改变习惯的问题，而是一个适合让 AI 先接管前置整理的机会。",
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
            "rest": {"休息", "放松", "睡觉", "午休", "恢复", "发呆", "散步", "休憩", "rest", "relax"},
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

        return {
            "acknowledgement": acknowledgement.strip(),
            "observation": observation.strip(),
            "try_next": try_next.strip(),
        }

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
