from __future__ import annotations

from collections import Counter

from app.schemas.self_review_schema import SelfReviewRequest, SelfReviewResponse
from app.services.classification_service import ClassificationService


class SelfReviewService:
    def generate(self, request: SelfReviewRequest) -> SelfReviewResponse:
        entries = [e for e in request.entries if e.content.strip()]
        language = ClassificationService().normalize_language(
            request.language,
            content=" ".join(entry.content for entry in entries),
        )
        if not entries:
            closing_note = {
                "zh-Hans": "先继续留下几条真实记录，专题式梳理才会更有抓手。",
                "zh-Hant": "先繼續留下幾條真實記錄，專題式整理才會更有抓手。",
                "ja": "まずは実際の記録をもう少し残してみましょう。記録が増えると、テーマを絞った振り返りがしやすくなります。",
                "en": "Keep a few more real entries first. A focused review will become more grounded.",
            }[language]
            return SelfReviewResponse(
                status="insufficient_data",
                reviewed_days=0,
                repeated_blockers=[],
                main_drains=[],
                helping_patterns=[],
                closing_note=closing_note,
            )

        top_tokens = [t for t in request.top_tokens if t.strip()]
        token_focus = top_tokens[0] if top_tokens else {
            "zh-Hans": "最近反复出现的主题",
            "zh-Hant": "最近反覆出現的主題",
            "ja": "最近繰り返し現れるテーマ",
            "en": "a recently recurring theme",
        }[language]
        reviewed_days = max(request.total_days, 1)

        emotion_counter = Counter((e.emotion or "neutral") for e in entries)
        scene_counter: Counter[str] = Counter()
        for e in entries:
            for tag in e.scene_tags:
                normalized = tag.strip()
                if normalized:
                    scene_counter[normalized] += 1

        top_scene = scene_counter.most_common(1)[0][0] if scene_counter else None
        top_scene = self._scene_label(top_scene, language) if top_scene else None
        strongest_entry = max(
            entries,
            key=lambda e: len((e.content or "").strip()),
        )
        concrete_fragment = strongest_entry.content.strip()
        if len(concrete_fragment) > 36:
            concrete_fragment = concrete_fragment[:36] + "..."

        if language != "zh-Hans":
            return self._generate_localized(
                language=language,
                request=request,
                reviewed_days=reviewed_days,
                token_focus=token_focus,
                top_scene=top_scene,
                concrete_fragment=concrete_fragment,
                negative_count=emotion_counter["negative"],
                positive_count=emotion_counter["positive"],
            )

        repeated_blockers = [
            f"“{token_focus}” 已经不是一次性的片段，而是在最近这段时间里反复回来；例如“{concrete_fragment}”这样的记录，不只是内容本身，也是在提示一种重复入口。",
            (
                f"高频场景更集中在“{top_scene}”，说明你被牵动的地方开始有固定入口。"
                if top_scene
                else "这些线索开始在几个相似瞬间里重复，说明它们值得被单独拿出来看。"
            ),
        ]

        if emotion_counter["negative"] >= max(emotion_counter["positive"], 1):
            main_drains = [
                f"最近最稳定的消耗，更像是“{top_scene or token_focus}”相关的场景在持续磨你，而不是某一件事突然变得很大。",
                "比起单个事件本身，更值得看的，是那种‘又来了’的熟悉消耗感：它通常意味着你在进入同一类判断成本。",
            ]
        else:
            main_drains = [
                f"你最近并不只是被压着走，但真正耗人的地方还是“{top_scene or token_focus}”一类时刻：它不一定强烈，却会反复占用注意力。",
                "有些看似轻一点的记录，背后仍然有同样的消耗结构，所以它们适合被放在同一个专题里看。",
            ]

        helping_patterns = [
            "你已经不是完全没有恢复力了；能把片段写下来，本身就是在把模糊压力变成可观察对象。",
            (
                "当你把事情写具体之后，后面的判断会明显更清楚，尤其是能看见问题发生在开始、推进，还是收尾。"
                if request.entry_count >= 3
                else "继续把最卡的瞬间写具体，会更容易看见真正有用的方法，而不是只得到一句泛泛的安慰。"
            ),
        ]

        closing_note = (
            f"先别急着一次性解决全部问题。这份自我回顾更适合帮你收窄注意力：接下来先继续盯住“{top_scene or token_focus}”，"
            "每次它出现时只多补一句：它是在什么场景、哪个阶段、被什么触发。这样下一次整理会更像判断，而不是重复总结。"
        )

        return SelfReviewResponse(
            status="ready",
            reviewed_days=reviewed_days,
            repeated_blockers=repeated_blockers,
            main_drains=main_drains,
            helping_patterns=helping_patterns,
            closing_note=closing_note,
        )

    def _generate_localized(
        self,
        *,
        language: str,
        request: SelfReviewRequest,
        reviewed_days: int,
        token_focus: str,
        top_scene: str | None,
        concrete_fragment: str,
        negative_count: int,
        positive_count: int,
    ) -> SelfReviewResponse:
        focus = top_scene or token_focus
        copy = {
            "zh-Hant": {
                "blocker_1": f"「{token_focus}」已不只是一次性的片段，而是在最近這段時間反覆出現；例如「{concrete_fragment}」這樣的記錄，也在提示一個重複入口。",
                "blocker_scene": f"高頻場景較集中在「{top_scene}」，顯示牽動你的地方開始有較固定的入口。" if top_scene else "這些 Signal 開始在幾個相似瞬間重複，值得單獨拿出來看。",
                "drain_negative": f"最近較穩定的消耗，像是與「{focus}」相關的場景持續磨耗你，而不是某件事突然變得很大。",
                "drain_other": f"你最近不只是被壓著走，但真正耗人的仍是「{focus}」一類時刻：它不一定強烈，卻會反覆佔用注意力。",
                "drain_2": "比起單一事件，更值得看的，是那種「又來了」的熟悉消耗感；它通常表示你又進入同一類判斷成本。",
                "help_1": "你並非完全沒有恢復力；能把片段寫下來，本身就是把模糊壓力變成可觀察的 Signal。",
                "help_2": "把事情寫得具體後，後續判斷會更清楚，尤其能看見問題出現在開始、推進，還是收尾。" if request.entry_count >= 3 else "繼續把最卡的瞬間寫具體，會更容易看見真正有用的方法。",
                "closing": f"先不用一次解決所有問題。這份自我回顧更適合幫你收窄注意力：接下來先留意「{focus}」，每次出現時只補一句場景、階段和觸發點。",
            },
            "ja": {
                "blocker_1": f"「{token_focus}」は一度きりではなく、最近繰り返し現れています。「{concrete_fragment}」のような記録も、同じ入口を示しています。",
                "blocker_scene": f"よく現れる場面は「{top_scene}」に集まっており、気持ちが動く入口が少し固定されてきています。" if top_scene else "これらの Signal は似た瞬間に繰り返し現れ、個別に見る価値があります。",
                "drain_negative": f"最近続いている負担は、何か一つが急に大きくなったというより、「{focus}」に関わる場面が少しずつ消耗させているようです。",
                "drain_other": f"最近は負担だけではありませんが、「{focus}」に関わる瞬間は、強くなくても繰り返し注意を奪っています。",
                "drain_2": "一つの出来事より、「また来た」と感じる慣れた消耗に注目すると、同じ判断の負担が見えやすくなります。",
                "help_1": "回復する力がなくなったわけではありません。出来事を記録すること自体が、曖昧な負担を観察できる Signal に変えています。",
                "help_2": "具体的に書くほど、問題が始まり、進行中、終わりのどこで起きるか判断しやすくなります。" if request.entry_count >= 3 else "いちばん引っかかった瞬間を具体的に残すと、役立つ方法が見えやすくなります。",
                "closing": f"一度に全部を解決しなくて大丈夫です。この振り返りでは、まず「{focus}」に注意を絞り、現れた場面、段階、きっかけを一言だけ足してみましょう。",
            },
            "en": {
                "blocker_1": f"“{token_focus}” is no longer a one-off moment; it has returned recently. Entries such as “{concrete_fragment}” point to a recurring entry point.",
                "blocker_scene": f"Frequent situations cluster around “{top_scene},” suggesting that the point that affects you is becoming more consistent." if top_scene else "These Signals repeat across similar moments and are worth reviewing on their own.",
                "drain_negative": f"The most consistent drain seems to come from situations around “{focus},” rather than one event suddenly becoming large.",
                "drain_other": f"You have not only been under pressure, but moments around “{focus}” still repeatedly occupy attention even when they are not intense.",
                "drain_2": "More than any one event, the familiar feeling of “here it is again” may show the same kind of decision cost returning.",
                "help_1": "Your capacity to recover has not disappeared. Writing down a moment already turns vague pressure into an observable Signal.",
                "help_2": "When entries are concrete, it becomes easier to see whether the difficulty occurs at the beginning, middle, or end." if request.entry_count >= 3 else "Keep the most difficult moments concrete so useful approaches can emerge.",
                "closing": f"There is no need to solve everything at once. Narrow attention to “{focus},” and when it appears, add one sentence about the situation, stage, and trigger.",
            },
        }[language]
        return SelfReviewResponse(
            status="ready",
            reviewed_days=reviewed_days,
            repeated_blockers=[copy["blocker_1"], copy["blocker_scene"]],
            main_drains=[
                copy["drain_negative"] if negative_count >= max(positive_count, 1) else copy["drain_other"],
                copy["drain_2"],
            ],
            helping_patterns=[copy["help_1"], copy["help_2"]],
            closing_note=copy["closing"],
        )

    def _scene_label(self, scene: str, language: str) -> str:
        labels = {
            "zh-Hans": {
                "work": "工作",
                "relationship": "关系",
                "body": "身体",
                "rest": "休息",
                "daily_life": "日常生活",
            },
            "zh-Hant": {
                "work": "工作",
                "relationship": "關係",
                "body": "身體",
                "rest": "休息",
                "daily_life": "日常生活",
            },
            "ja": {
                "work": "仕事",
                "relationship": "人間関係",
                "body": "身体",
                "rest": "休息",
                "daily_life": "日常生活",
            },
            "en": {},
        }
        return labels.get(language, {}).get(scene, scene)
