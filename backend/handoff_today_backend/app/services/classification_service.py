from app.rules.classify_rules import classify_capture


class ClassificationService:
    def classify_capture(self, content: str, tag_hint: str | None = None) -> dict:
        return classify_capture(content, tag_hint)

    def generate_acknowledgement(self, content: str, classified_signal: dict) -> str:
        scene = classified_signal.get('scene_type')
        if classified_signal.get('signal_type') == 'desire':
            return '我记下来了，这更像是你明确想省掉的一步。'
        if classified_signal.get('signal_type') == 'repetition':
            if scene == 'information_gathering':
                return '我先记下来了，这更像是一次重复的资料整理。'
            return '我先记下来了，这像是一个反复出现的模式。'
        if classified_signal.get('signal_type') == 'friction':
            return '我记下这个卡点了，后面我会看看它是不是在重复出现。'
        return '我先把这条生活信号记下来了。'
