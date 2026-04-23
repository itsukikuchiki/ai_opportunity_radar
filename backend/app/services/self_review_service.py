from __future__ import annotations

from collections import Counter

from app.schemas.self_review_schema import SelfReviewRequest, SelfReviewResponse


class SelfReviewService:
    def generate(self, request: SelfReviewRequest) -> SelfReviewResponse:
        entries = [e for e in request.entries if e.content.strip()]
        if not entries:
            return SelfReviewResponse(
                status="insufficient_data",
                reviewed_days=0,
                repeated_blockers=[],
                main_drains=[],
                helping_patterns=[],
                closing_note="先继续留下几条真实记录，专题式梳理才会更有抓手。",
            )

        top_tokens = [t for t in request.top_tokens if t.strip()]
        token_focus = top_tokens[0] if top_tokens else "最近反复出现的主题"
        reviewed_days = max(request.total_days, 1)

        emotion_counter = Counter((e.emotion or "neutral") for e in entries)
        scene_counter: Counter[str] = Counter()
        for e in entries:
            for tag in e.scene_tags:
                normalized = tag.strip()
                if normalized:
                    scene_counter[normalized] += 1

        top_scene = scene_counter.most_common(1)[0][0] if scene_counter else None
        repeated_blockers = [
            f"“{token_focus}” 已经不是一次性的片段，而是在最近这段时间里反复回来。",
            (
                f"高频场景更集中在“{top_scene}”，说明你被牵动的地方开始有固定入口。"
                if top_scene
                else "这些线索开始在几个相似瞬间里重复，说明它们值得被单独拿出来看。"
            ),
        ]

        if emotion_counter["negative"] >= max(emotion_counter["positive"], 1):
            main_drains = [
                f"最近最稳定的消耗，更像是“{top_scene or token_focus}”相关的场景在持续磨你。",
                "比起单个事件本身，更值得看的，是那种‘又来了’的熟悉消耗感。",
            ]
        else:
            main_drains = [
                f"你最近并不只是被压着走，真正耗人的地方还是“{top_scene or token_focus}”一类时刻。",
                "有些看似轻一点的记录，背后仍然有同样的消耗结构。",
            ]

        helping_patterns = [
            "你已经不是完全没有恢复力了，一些小的缓冲动作正在慢慢起作用。",
            (
                "当你把事情写具体之后，后面的判断会明显更清楚。"
                if request.entry_count >= 3
                else "继续把最卡的瞬间写具体，会更容易看见真正有用的方法。"
            ),
        ]

        closing_note = (
            f"先别急着一次性解决全部问题。这份 self-review 更适合帮你收窄注意力：接下来先继续盯住“{top_scene or token_focus}”，"
            "看它到底是在什么条件下最容易出现。"
        )

        return SelfReviewResponse(
            status="ready",
            reviewed_days=reviewed_days,
            repeated_blockers=repeated_blockers,
            main_drains=main_drains,
            helping_patterns=helping_patterns,
            closing_note=closing_note,
        )
