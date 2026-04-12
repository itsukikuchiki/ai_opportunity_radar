from __future__ import annotations

from collections import Counter
from typing import Any

from app.schemas.ai_schema import (
    CaptureReplyResponse,
    JourneyGenerateRequest,
    JourneyGenerateResponse,
    TodaySummaryRequest,
    TodaySummaryResponse,
    WeeklyGenerateRequest,
    WeeklyGenerateResponse,
)
from app.services.classification_service import ClassificationService


class AiGenerationService:
    def __init__(self) -> None:
        self.classification_service = ClassificationService()

    def generate_capture_reply(self, payload: dict[str, Any]) -> CaptureReplyResponse:
        content = (payload.get("content") or "").strip()
        recent_assistant_texts = payload.get("recent_assistant_texts") or []

        classified_signal = self.classification_service.classify_capture(
            content=content,
            tag_hint=None,
        )
        acknowledgement = self.classification_service.generate_acknowledgement(
            content=content,
            classified_signal=classified_signal,
            recent_assistant_texts=recent_assistant_texts,
        )

        followup = None
        return CaptureReplyResponse(
            acknowledgement=acknowledgement,
            followup=followup,
        )

    def generate_today_summary(
        self,
        request: TodaySummaryRequest,
    ) -> TodaySummaryResponse:
        entries = request.entries
        count = request.entry_count or len(entries)

        if count <= 0:
            return TodaySummaryResponse(
                observation="今天还没有记录，先留下一件真实发生的小事就好。",
                suggestion="今天先记下一件让你停顿了一下的小事就好。",
            )

        contents = [e.content.strip() for e in entries if e.content and e.content.strip()]
        top_theme = self._top_theme(contents)

        if count == 1:
            observation = f"今天记录了 1 条，线索开始出现了。最明显的是“{top_theme}”。"
            suggestion = "如果今天同类事情再出现一次，就再补记一条，把场景也一起留下来。"
        else:
            observation = f"今天记录了 {count} 条，几条线索已经开始往“{top_theme}”上聚。"
            suggestion = f"今天可以先试试：下次再出现“{top_theme}”时，用一句话补记它发生在什么场景。"

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
            {
                "name": "重复出现的主题",
                "summary": f"这周几条记录开始往“{top_token}”上聚，说明它已经不只是一次性的瞬间。",
            },
            {
                "name": f"高频关键词：{top_token}",
                "summary": f"从这周的本地统计看，“{top_token}”是目前最明显的长期线索之一。",
            },
        ]

        frictions = [
            {
                "name": "本周的主要消耗",
                "summary": f"这周更像是同类问题反复回来，而不是单次事件；其中 {peak_day} 的 signal 更集中。",
            },
        ]

        best_action = f"这周先试一步：下次再出现“{top_token}”时，用一句话补记它发生在什么场景。"

        opportunity_snapshot = {
            "name": "把重复信号固定下来",
            "summary": f"如果“{top_token}”总是回来，它很适合先被结构化记录，再观察是否值得进一步模板化。",
        }

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
                {
                    "name": "反复出现的主题",
                    "summary": f"一路看下来，“{top_token}”开始不止一次地出现，说明它已经在慢慢形成长期模式。",
                }
            ],
            frictions=[
                {
                    "name": "持续性的摩擦",
                    "summary": "这段时间里，有些问题不是一次性的，而是在慢慢累积，开始形成稳定摩擦。",
                }
            ],
            desires=[
                {
                    "name": "还在浮现的方向",
                    "summary": f"记录已经跨越 {total_days} 天，一些真正长期在意的方向正在慢慢浮现。",
                }
            ],
            experiments=[
                {
                    "name": "开始有帮助的东西",
                    "summary": "继续记录下去，会更容易看见什么做法不是偶然有效，而是在慢慢变得有帮助。",
                }
            ],
        )

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
