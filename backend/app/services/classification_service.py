from __future__ import annotations

from app.rules.classify_rules import classify_capture


class ClassificationService:
    immediate_risk_phrases = {
        "想自杀",
        "要自杀",
        "不想活了",
        "结束生命",
        "伤害自己",
        "杀了自己",
        "想杀人",
        "伤害别人",
        "今すぐ死にたい",
        "自殺したい",
        "自分を傷つける",
        "kill myself",
        "suicide now",
        "end my life",
        "hurt myself",
        "hurt someone",
    }

    def classify_capture(self, content: str, tag_hint: str | None = None) -> dict:
        return classify_capture(content, tag_hint)

    def is_immediate_safety_risk(self, content: str) -> bool:
        normalized = (content or "").strip().lower()
        return bool(normalized) and any(
            phrase in normalized for phrase in self.immediate_risk_phrases
        )

    def immediate_safety_acknowledgement(self) -> str:
        return (
            "我很在意你刚才这句话。若你现在可能马上伤害自己或他人，"
            "请先离开危险物品并联系当地紧急服务，或立刻联系一个能到你身边的可信任的人。"
            "如果可以，只回复我：你现在是否处于立即危险中？"
        )

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

        specific = self._specific_reply(
            text=text,
            lang=lang,
            mood=mood,
            axis=axis,
        )
        if specific and specific not in recent_tail:
            return specific

        pool = self._reply_pool(lang=lang, mood=mood, axis=axis)
        candidates = [item for item in pool if item not in recent_tail]
        if not candidates:
            candidates = pool

        return candidates[len(text) % len(candidates)]

    def _specific_reply(self, *, text: str, lang: str, mood: str, axis: str) -> str | None:
        topic = self._topic_hint(text)
        if not topic:
            return None

        if lang == "ja":
            return self._specific_reply_ja(topic=topic, mood=mood, axis=axis)
        if lang == "en":
            return self._specific_reply_en(topic=topic, mood=mood, axis=axis)
        return self._specific_reply_zh(topic=topic, mood=mood, axis=axis)

    def _specific_reply_zh(self, *, topic: str, mood: str, axis: str) -> str:
        if topic == "cost":
            return "你写下了 token 成本很高，这份在意先留在这里。"
        if topic == "horse_expectation":
            return "你提到了骑马和期待，这个片刻先留在这里。"
        if topic == "tomorrow_uncertainty":
            return "你写下了明天无法预测，也想好好看着当下。"
        if topic == "retirement_wish":
            return "你写下了想早点退休，这个念头先留在这里。"
        if topic == "weather_good":
            return "你留意到今天天气不错，这个小片刻先记下来了。"
        if topic == "rest_wish":
            return "你写下了想停下来休息，这个感受先留在这里。"
        if topic == "money":
            return "你写下了对钱、成本或预算的在意，这一条先留在这里。"
        return ""

    def _specific_reply_ja(self, *, topic: str, mood: str, axis: str) -> str:
        if topic == "cost":
            return "token のコストが高いと感じたことを、そのままここに残します。"
        if topic == "horse_expectation":
            return "乗馬を楽しみにしている気持ちを、ここに残します。"
        if topic == "tomorrow_uncertainty":
            return "明日は予測できず、今を大切にしたいと書いてくれましたね。"
        if topic == "retirement_wish":
            return "早く引退したいという今の気持ちを、まずここに残します。"
        if topic == "weather_good":
            return "今日は天気がいいと感じた、その小さな瞬間を残します。"
        if topic == "rest_wish":
            return "少し止まって休みたいという気持ちを、ここに残します。"
        if topic == "money":
            return "お金やコスト、予算が気になったことを、ここに残します。"
        return ""

    def _specific_reply_en(self, *, topic: str, mood: str, axis: str) -> str:
        if topic == "cost":
            return "You wrote that token cost feels high, and I am keeping that concern here."
        if topic == "horse_expectation":
            return "You mentioned looking forward to horse riding, and I am keeping that moment here."
        if topic == "tomorrow_uncertainty":
            return "You wrote that tomorrow cannot be predicted and that you want to stay with the present."
        if topic == "retirement_wish":
            return "You wrote that you want to retire early, and I am keeping that thought here."
        if topic == "weather_good":
            return "You noticed that the weather feels good today, and I am keeping that small moment here."
        if topic == "rest_wish":
            return "You wrote that you want to stop and rest for a while, and I am keeping that feeling here."
        if topic == "money":
            return "You wrote that money, cost, or budget is on your mind, and I am keeping that here."
        return ""

    def _topic_hint(self, text: str) -> str | None:
        lowered = text.lower()
        if self._contains_any(lowered, ["token", "tokens", "トークン"]) and self._contains_any(
            lowered,
            ["贵", "高", "expensive", "cost", "高い"],
        ):
            return "cost"
        if self._contains_any(lowered, ["骑马", "馬", "乗馬", "horse"]):
            if self._contains_any(
                lowered,
                ["期待", "开心", "值得", "楽しみ", "嬉しい", "look forward", "happy"],
            ):
                return "horse_expectation"
            return "horse_expectation"
        if self._contains_any(
            lowered,
            ["无法预测明天", "不能预测明天", "预测明天", "活在当下", "tomorrow", "明日", "予測", "present"],
        ):
            return "tomorrow_uncertainty"
        if self._contains_any(lowered, ["退休", "退職", "引退", "retire"]):
            return "retirement_wish"
        if self._contains_any(lowered, ["天气不错", "好天气", "いい天気", "weather is nice", "good weather"]):
            return "weather_good"
        if self._contains_any(lowered, ["休息", "不想上班", "想停", "早日退", "休みたい", "rest"]):
            return "rest_wish"
        if self._contains_any(lowered, ["钱", "贵", "预算", "成本", "花费", "价格", "お金", "cost", "money", "budget"]):
            return "money"
        return None

    def _reply_pool(self, *, lang: str, mood: str, axis: str) -> list[str]:
        if lang == "ja":
            return self._reply_pool_ja(mood=mood, axis=axis)
        if lang == "en":
            return self._reply_pool_en(mood=mood, axis=axis)
        return self._reply_pool_zh(mood=mood, axis=axis)

    def _reply_pool_zh(self, *, mood: str, axis: str) -> list[str]:
        if axis == "unfairness":
            return [
                "你写下了本不该由你承担的事情落到了你这里。",
                "这件事让你觉得不公平，这份感受先留在这里。",
            ]
        if axis == "interruption":
            return [
                "你写下了节奏一直被打断和切换。",
                "反复被打断的感受，我先按你写下的留在这里。",
            ]
        if axis == "repetition":
            return [
                "你写下了又要重来一遍，这种感受先留在这里。",
                "这次反复和重做，已经被你记下来了。",
            ]
        if axis == "confirmation":
            return [
                "你写下了反复确认和对齐，这一条先留在这里。",
                "这次来回确认的经历，已经被记下来了。",
            ]
        if axis == "overload":
            return [
                "你写下了事情太多、太杂，这种状态先留在这里。",
                "这些同时出现的事情，已经被你记下来了。",
            ]
        if axis == "confusion":
            return [
                "你写下了现在还不知道怎么办，这份不确定先留在这里。",
                "此刻方向还不清楚，这个感受已经被记下来了。",
            ]
        if axis == "pleasant_moment":
            return [
                "你写下了这个开心或轻松的片刻。",
                "这个让你感觉不错的瞬间，已经被记下来了。",
            ]
        if mood == "positive":
            return [
                "我听见你说这一刻感觉不错，先把它留在这里。",
                "你写下了一个开心的片刻，这一条已经记下来了。",
            ]
        if mood == "negative":
            return [
                "我听见你说这一刻很难受，这份感受先留在这里。",
                "你写下了现在的不舒服，这一条已经记下来了。",
            ]
        if mood == "mixed":
            return [
                "你写下了几种交在一起的感受，先原样留在这里。",
                "此刻的感受有些复杂，这一条已经记下来了。",
            ]
        return [
            "你写下的这件事已经留在这里了。",
            "这一条已经按你写下的内容记下来了。",
        ]

    def _reply_pool_ja(self, *, mood: str, axis: str) -> list[str]:
        if axis == "unfairness":
            return [
                "本来あなたが引き受けるはずではないことが来た、と書いてくれましたね。",
                "不公平だと感じたことを、そのままここに残します。",
            ]
        if axis == "interruption":
            return [
                "流れが何度も中断され、切り替えが続いたと書いてくれましたね。",
                "何度も中断された感覚を、そのままここに残します。",
            ]
        if axis == "repetition":
            return [
                "またやり直すことになった、と書いてくれましたね。",
                "今回の繰り返しを、そのままここに残します。",
            ]
        if axis == "confirmation":
            return [
                "確認や調整を何度も繰り返した、と書いてくれましたね。",
                "今回の行き来を、そのままここに残します。",
            ]
        if axis == "overload":
            return [
                "やることが多く、いろいろ重なっていると書いてくれましたね。",
                "今いくつも重なっている状態を、ここに残します。",
            ]
        if axis == "confusion":
            return [
                "今はどうしたらよいかわからない、と書いてくれましたね。",
                "方向がまだ見えない感覚を、ここに残します。",
            ]
        if axis == "pleasant_moment":
            return [
                "嬉しい、楽しいと感じたこの瞬間を、ここに残します。",
                "気分がよかったこの瞬間を記録しました。",
            ]
        if mood == "positive":
            return [
                "今いい気分だと書いてくれましたね。そのまま残します。",
                "この嬉しい瞬間を記録しました。",
            ]
        if mood == "negative":
            return [
                "今つらい、しんどいと感じていることを、ここに残します。",
                "この不快な感覚を、そのまま記録しました。",
            ]
        if mood == "mixed":
            return [
                "いくつかの気持ちが混ざっていることを、そのまま残します。",
                "今の複雑な感覚を記録しました。",
            ]
        return [
            "書いてくれたことを、そのままここに残します。",
            "この出来事を記録しました。",
        ]

    def _reply_pool_en(self, *, mood: str, axis: str) -> list[str]:
        if axis == "unfairness":
            return [
                "You wrote that something you should not have had to carry landed on you.",
                "You felt this was unfair, and I am keeping that feeling here.",
            ]
        if axis == "interruption":
            return [
                "You wrote that your flow kept being interrupted and switched.",
                "I am keeping the experience of being interrupted again and again here.",
            ]
        if axis == "repetition":
            return [
                "You wrote that you had to do it over again, and I am keeping that here.",
                "This repetition and redo has been recorded.",
            ]
        if axis == "confirmation":
            return [
                "You wrote that you had to check and align things repeatedly.",
                "This back-and-forth checking has been recorded.",
            ]
        if axis == "overload":
            return [
                "You wrote that there are too many things at once, and I am keeping that state here.",
                "These overlapping things have been recorded.",
            ]
        if axis == "confusion":
            return [
                "You wrote that you do not know what to do right now, and I am keeping that uncertainty here.",
                "The direction still feels unclear, and that has been recorded.",
            ]
        if axis == "pleasant_moment":
            return [
                "You wrote that this moment felt happy or light, and I am keeping it here.",
                "This good-feeling moment has been recorded.",
            ]
        if mood == "positive":
            return [
                "I hear that this moment felt good, and I am keeping it here.",
                "You wrote down a happy moment, and it has been recorded.",
            ]
        if mood == "negative":
            return [
                "I hear that this moment felt hard, and I am keeping that feeling here.",
                "You wrote down this discomfort, and it has been recorded.",
            ]
        if mood == "mixed":
            return [
                "You wrote down several mixed feelings, and I am keeping them as they are.",
                "This complex feeling has been recorded.",
            ]
        return [
            "I am keeping what you wrote here as it is.",
            "This event has been recorded.",
        ]

    def _detect_mood(self, text: str) -> str:
        positive = self._contains_any(text, [
            "开心", "高兴", "快乐", "舒服", "不错", "很好", "轻松", "喜欢", "幸福",
            "開心", "高興", "快樂", "不錯", "輕鬆", "喜歡",
            "嬉しい", "楽しい", "気分いい", "いい天気", "よかった", "気持ちいい", "幸せ",
            "happy", "good", "great", "nice", "glad", "relieved"
        ])
        negative = self._contains_any(text, [
            "烦", "烦躁", "崩溃", "受不了", "生气", "不开心", "委屈", "累", "疲惫", "困",
            "煩", "煩躁", "崩潰", "受不了", "生氣", "不開心", "委屈", "疲憊",
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
            "憑啥", "為什麼要我", "不是我", "他們自己負責", "甩給我", "讓我負責",
            "なんで私", "自分で責任", "押しつけ", "尻ぬぐい", "後始末",
            "why me", "their responsibility", "pushed onto me", "not mine"
        ])
        if unfair:
            return "unfairness"

        interrupt = self._contains_any(text, [
            "打断", "切换", "分心", "插进来", "上下文",
            "打斷", "切換", "插進來",
            "中断", "割り込み", "切り替え",
            "interrupted", "context switch", "broken flow"
        ])
        if interrupt:
            return "interruption"

        confirmation = self._contains_any(text, [
            "确认", "顺序", "对齐", "协调", "沟通",
            "確認", "順序", "對齊", "協調", "溝通",
            "確認", "順番", "調整", "共有",
            "confirm", "recheck", "align", "coordinate"
        ])
        if confirmation:
            return "confirmation"

        repetition = self._contains_any(text, [
            "又", "重复", "重新", "反复", "再",
            "重複", "反覆",
            "また", "何度も", "繰り返し",
            "again", "redo", "repeat"
        ])
        if repetition:
            return "repetition"

        overload = self._contains_any(text, [
            "项目太多", "事情太多", "工作太杂", "一堆事", "太多了",
            "項目太多", "工作太雜",
            "多すぎる", "仕事が多い", "雑多",
            "too much", "too many things", "messy", "overloaded"
        ])
        if overload:
            return "overload"

        confusion = self._contains_any(text, [
            "不知道怎么办", "不知道该怎么办", "不知道怎么做", "没办法", "不知道",
            "不知道怎麼辦", "不知道該怎麼辦", "不知道怎麼做", "沒辦法",
            "どうしたらいい", "わからない",
            "don't know what to do", "stuck", "lost"
        ])
        if confusion:
            return "confusion"

        pleasant = self._contains_any(text, [
            "开心", "高兴", "快乐", "舒服", "不错", "很好", "轻松", "喜欢", "幸福",
            "開心", "高興", "快樂", "不錯", "輕鬆", "喜歡",
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
    
