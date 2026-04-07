from __future__ import annotations

from app.rules.classify_rules import classify_capture


class ClassificationService:
    def classify_capture(self, content: str, tag_hint: str | None = None) -> dict:
        return classify_capture(content, tag_hint)

    def generate_acknowledgement(
        self,
        content: str,
        classified_signal: dict | None = None,
        recent_assistant_texts: list[str] | None = None,
    ) -> str:
        text = (content or "").strip()
        recent_assistant_texts = recent_assistant_texts or []
        recent_tail = [x.strip() for x in recent_assistant_texts if x and x.strip()][-2:]

        lang = self._detect_language(text)
        mood = self._detect_mood(text)
        axis = self._detect_axis(text)

        pool = self._reply_pool(lang=lang, mood=mood, axis=axis)
        candidates = [item for item in pool if item not in recent_tail]
        if not candidates:
            candidates = pool

        return candidates[len(text) % len(candidates)]

    def _reply_pool(self, *, lang: str, mood: str, axis: str) -> list[str]:
        if lang == "ja":
            return self._reply_pool_ja(mood=mood, axis=axis)
        if lang == "en":
            return self._reply_pool_en(mood=mood, axis=axis)
        return self._reply_pool_zh(mood=mood, axis=axis)

    def _reply_pool_zh(self, *, mood: str, axis: str) -> list[str]:
        if axis == "unfairness":
            return [
                "最让人难受的不是事情本身，而是本该别人承担的东西最后落到了你这里。",
                "这不只是烦，是责任和收尾最后压到了你身上。",
                "刺的地方不是任务，而是明明不是你出的错，却变成你来扛。",
            ]
        if axis == "interruption":
            return [
                "这种一直被切断的感觉，很容易把人磨烦。",
                "真正消耗你的，好像不是量本身，而是节奏总被打散。",
                "一旦不停切换，人就很难把心收稳。",
            ]
        if axis == "repetition":
            return [
                "这种“又要来一遍”的感觉，真的很磨人。",
                "重复本身就很消耗，难受是正常的。",
                "像这种来回重做，心力会被悄悄吃掉。",
            ]
        if axis == "confirmation":
            return [
                "一遍遍确认这种事，看着小，其实特别耗人。",
                "反复对齐和确认，很容易把心力切走。",
                "来回确认最磨心力，这一下我先帮你接住。",
            ]
        if axis == "overload":
            return [
                "这不像只是一句烦，更像事情太多太杂，一起压上来了。",
                "不是你扛不住，是这些东西同时压过来，本来就很耗人。",
                "这种杂和乱叠在一起，很容易把人拖住。",
            ]
        if axis == "confusion":
            return [
                "先不用急着把路想清楚，能把这一下留下来就已经很好了。",
                "这种一下没方向的感觉，我先陪你接住。",
                "现在不急着解释清楚，先把它留在这里也可以。",
            ]
        if axis == "pleasant_moment":
            return [
                "这种轻一点、亮一点的感觉，也值得记下来。",
                "嗯，这种小小的开心不是边角料，也是今天的一部分。",
                "这种舒服和快乐留下来也很有意义。",
            ]
        if mood == "positive":
            return [
                "这一下是亮的，也值得留下来。",
                "这种舒服的瞬间，本身就很有价值。",
                "今天不只有消耗，也有让你松一点的时刻。",
            ]
        if mood == "negative":
            return [
                "这一下听着就挺难受的，先别急着往下扛。",
                "这种不舒服不是小事，先让它停在这里。",
                "看着像一句话，但这种感觉会一直挂着。",
            ]
        if mood == "mixed":
            return [
                "这一下里面不只是一个感觉，先别急着把它压平。",
                "这种有点乱、有点杂的感受，也值得先留住。",
                "先别急着分清哪一种，先把这一团感觉放在这里。",
            ]
        return [
            "好，我接住了，先把这个点放在这里。",
            "先不用急着解释清楚，能把它留下来就很好。",
            "这种小瞬间其实也很有信息量，后面再慢慢看。",
        ]

    def _reply_pool_ja(self, *, mood: str, axis: str) -> list[str]:
        if axis == "unfairness":
            return [
                "いちばんしんどいのは仕事そのものじゃなくて、本来向こうが持つはずの責任が最後にあなたへ来ていることですね。",
                "これはただの苛立ちじゃなくて、責任を押しつけられている感じですね。",
                "刺さるのは作業よりも、最後に自分が引き受ける形になっていることですね。",
            ]
        if axis == "interruption":
            return [
                "ずっと流れを切られる感じが、かなり消耗しますよね。",
                "量よりも、リズムを何度も崩されているのがしんどそうです。",
                "何回も切り替えさせられると、それだけで疲れますよね。",
            ]
        if axis == "repetition":
            return [
                "またやり直す感じ、それだけでかなり削られますよね。",
                "繰り返しそのものが、静かにしんどいですね。",
                "同じことをもう一度やる感覚、かなり心力を持っていかれます。",
            ]
        if axis == "confirmation":
            return [
                "何度も確認し直すの、かなり消耗しますよね。",
                "小さく見えても、こういう行ったり来たりは本当にしんどいです。",
                "順番や認識を合わせ直す感じ、かなり削られますね。",
            ]
        if axis == "overload":
            return [
                "これは一言の苛立ちというより、いろんなものが重なって押してきていますね。",
                "弱いわけじゃなくて、ちゃんと負荷が積み上がっています。",
                "量と雑多さが一緒に来ると、それだけでかなりしんどいです。",
            ]
        if axis == "confusion":
            return [
                "いま無理に整理しなくて大丈夫です。まずはここに置いておきましょう。",
                "急に道が見えなくなる感じ、ありますよね。まずは残しておきましょう。",
                "まだ答えを出さなくて大丈夫です。この詰まり方自体が大事です。",
            ]
        if axis == "pleasant_moment":
            return [
                "こういう軽い嬉しさも、ちゃんと今日の一部ですね。",
                "うん、この感じは明るいです。残しておく価値があります。",
                "こういう小さい気分のよさも、大事にしていいと思います。",
            ]
        if mood == "positive":
            return [
                "この明るさも、ちゃんと残しておいていいです。",
                "こういういい感じも、今日の大事な線です。",
                "軽くなった感じ、ちゃんと意味があります。",
            ]
        if mood == "negative":
            return [
                "この感じ、かなり消耗しますよね。いったんここに置いておきましょう。",
                "一言に見えても、こういうしんどさは残りますよね。",
                "その引っかかり、無理に流さなくていいです。",
            ]
        if mood == "mixed":
            return [
                "この中には一つじゃない感じが入っていますね。まずはそのまま残しておきましょう。",
                "まだ整理しきれなくても大丈夫です。この混ざり方自体が大事です。",
                "すぐに言い切れなくても大丈夫です。まずは受け止めます。",
            ]
        return [
            "まずはここに置いておきましょう。",
            "無理に整理しなくて大丈夫です。",
            "この一瞬にもちゃんと意味があります。",
        ]

    def _reply_pool_en(self, *, mood: str, axis: str) -> list[str]:
        if axis == "unfairness":
            return [
                "What hurts here is not just the task itself, but that something that should have stayed with them ended up on you.",
                "This is not just annoyance. It feels like responsibility got pushed onto you.",
                "The hard part is not the work alone, but having to carry what should not have been yours.",
            ]
        if axis == "interruption":
            return [
                "It sounds less like pure volume and more like your rhythm keeps getting broken.",
                "Being interrupted again and again really does wear a person down.",
                "This feels exhausting not just because of the work, but because you cannot stay in one flow.",
            ]
        if axis == "repetition":
            return [
                "That “here we go again” feeling is genuinely wearing.",
                "Repeating the same thing again can drain more than it looks.",
                "This kind of redo takes energy quietly but steadily.",
            ]
        if axis == "confirmation":
            return [
                "Having to re-check things over and over is more draining than it seems.",
                "This kind of back-and-forth confirmation really does eat up energy.",
                "Even small repeated confirmations can wear you down a lot.",
            ]
        if axis == "overload":
            return [
                "This sounds bigger than a single complaint. It feels like too many things are piling up at once.",
                "It is not that you are weak. This is a real amount of pressure landing together.",
                "Too much at once, especially when it is all mixed together, is genuinely exhausting.",
            ]
        if axis == "confusion":
            return [
                "You do not have to make sense of it all right now. Leaving it here is already enough.",
                "That lost, stuck feeling matters too. We can keep it here first.",
                "You do not need an answer yet. This moment itself is worth keeping.",
            ]
        if axis == "pleasant_moment":
            return [
                "That lighter, brighter feeling is worth keeping too.",
                "This kind of small good moment matters as well.",
                "A gentle moment like this still deserves a place in today.",
            ]
        if mood == "positive":
            return [
                "This bright little moment matters too.",
                "Not everything today is heavy. This part is worth keeping.",
                "This light feeling belongs to today as much as everything else.",
            ]
        if mood == "negative":
            return [
                "That sounds genuinely hard. You do not need to push it away right now.",
                "This is not a small discomfort. We can leave it here first.",
                "Even in one sentence, I can feel that this lingers.",
            ]
        if mood == "mixed":
            return [
                "There is more than one feeling in this, and that already matters.",
                "You do not have to flatten this into one clean answer yet.",
                "It is okay if this still feels mixed. We can keep it as it is for now.",
            ]
        return [
            "Got it. We can leave this here first.",
            "You do not need to explain it fully yet.",
            "Even a small moment like this can carry meaning.",
        ]

    def _detect_mood(self, text: str) -> str:
        positive = self._contains_any(text, [
            "开心", "高兴", "快乐", "舒服", "不错", "很好", "轻松", "喜欢", "幸福",
            "嬉しい", "楽しい", "気分いい", "いい天気", "よかった", "気持ちいい", "幸せ",
            "happy", "good", "great", "nice", "glad", "relieved"
        ])
        negative = self._contains_any(text, [
            "烦", "烦躁", "崩溃", "受不了", "生气", "不开心", "委屈", "累", "疲惫", "困",
            "つらい", "イライラ", "しんどい", "疲れた",
            "annoyed", "tired", "upset", "bad", "frustrated", "angry", "exhausted"
        ])

        if positive and negative:
            return "mixed"
        if positive:
            return "positive"
        if negative:
            return "negative"
        return "neutral"

    def _detect_axis(self, text: str) -> str:
        unfair = self._contains_any(text, [
            "凭啥", "为什么要我", "不是我", "他们自己负责", "甩给我", "让我负责",
            "なんで私", "自分で責任", "押しつけ", "尻ぬぐい", "後始末",
            "why me", "their responsibility", "pushed onto me", "not mine"
        ])
        if unfair:
            return "unfairness"

        interrupt = self._contains_any(text, [
            "打断", "切换", "分心", "插进来", "上下文",
            "中断", "割り込み", "切り替え",
            "interrupted", "context switch", "broken flow"
        ])
        if interrupt:
            return "interruption"

        confirmation = self._contains_any(text, [
            "确认", "顺序", "对齐", "协调", "沟通",
            "確認", "順番", "調整", "共有",
            "confirm", "recheck", "align", "coordinate"
        ])
        if confirmation:
            return "confirmation"

        repetition = self._contains_any(text, [
            "又", "重复", "重新", "反复", "再",
            "また", "何度も", "繰り返し",
            "again", "redo", "repeat"
        ])
        if repetition:
            return "repetition"

        overload = self._contains_any(text, [
            "项目太多", "事情太多", "工作太杂", "一堆事", "太多了",
            "多すぎる", "仕事が多い", "雑多",
            "too much", "too many things", "messy", "overloaded"
        ])
        if overload:
            return "overload"

        confusion = self._contains_any(text, [
            "不知道怎么办", "不知道该怎么办", "不知道怎么做", "没办法", "不知道",
            "どうしたらいい", "わからない",
            "don't know what to do", "stuck", "lost"
        ])
        if confusion:
            return "confusion"

        pleasant = self._contains_any(text, [
            "开心", "高兴", "快乐", "舒服", "不错", "很好", "轻松", "喜欢", "幸福",
            "嬉しい", "楽しい", "気分いい", "いい天気", "よかった", "気持ちいい", "幸せ",
            "happy", "good", "great", "nice", "glad", "pleasant"
        ])
        if pleasant:
            return "pleasant_moment"

        return "general"

    def _contains_any(self, text: str, keywords: list[str]) -> bool:
        lowered = text.lower()
        return any(k.lower() in lowered for k in keywords)

    def _detect_language(self, text: str) -> str:
        has_kana = any(
            ('ぁ' <= ch <= 'ゖ') or ('ァ' <= ch <= 'ヺ')
            for ch in text
        )
        if has_kana:
            return "ja"

        has_cjk = any('\u4e00' <= ch <= '\u9fff' for ch in text)
        has_ascii = any(('a' <= ch.lower() <= 'z') for ch in text)

        if has_cjk:
            return "zh"
        if has_ascii:
            return "en"
        return "zh"
    
