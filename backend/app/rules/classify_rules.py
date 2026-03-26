from dataclasses import asdict, dataclass

REPETITION_KEYWORDS = ["又", "每次", "总是", "反复", "再一次", "老是"]
DESIRE_KEYWORDS = ["希望自动", "想省掉", "不想再做", "交给AI", "要是能自动"]
FRICTION_KEYWORDS = ["烦", "卡住", "拖住", "很麻烦", "受不了", "崩溃"]

SCENE_RULES = {
    "scheduling": ["排时间", "改计划", "改期", "排程", "日程"],
    "information_gathering": ["资料", "信息", "整理", "找", "上下文"],
    "writing": ["写", "草稿", "表达", "文章", "输出"],
    "decision_making": ["决定", "选择", "比较", "犹豫"],
    "communication": ["回复", "对齐", "沟通", "确认"],
}

FRICTION_RULES = {
    "time": ["没时间", "来不及", "改期", "拖延"],
    "information": ["找不到", "信息散", "整理", "资料太多", "上下文"],
    "decision": ["犹豫", "难决定", "比较半天"],
    "execution": ["开始不了", "推进不动", "被打断", "切换"],
    "coordination": ["来回确认", "协作", "对齐"],
    "emotional": ["烦", "累", "抗拒", "崩溃"],
}

@dataclass
class ClassifiedSignal:
    signal_type: str
    scene_type: str
    friction_type: str
    repetition_flag: bool
    desire_flag: bool
    emotion_strength: str


def contains_any(text: str, keywords: list[str]) -> bool:
    return any(k in text for k in keywords)


def normalize_text(text: str) -> str:
    return " ".join(text.strip().split())


def detect_scene_type(text: str) -> str:
    for scene_type, keywords in SCENE_RULES.items():
        if contains_any(text, keywords):
            return scene_type
    return "other"


def detect_friction_type(text: str) -> str:
    for friction_type, keywords in FRICTION_RULES.items():
        if contains_any(text, keywords):
            return friction_type
    return "unknown"


def detect_emotion_strength(text: str) -> str:
    if contains_any(text, ["崩溃", "受不了", "特别消耗"]):
        return "high"
    if contains_any(text, ["很烦", "卡住", "拖住"]):
        return "medium"
    return "low"


def classify_capture(content: str, tag_hint: str | None = None) -> dict:
    text = normalize_text(content)
    repetition_flag = contains_any(text, REPETITION_KEYWORDS)
    desire_flag = contains_any(text, DESIRE_KEYWORDS)
    signal_type = "life"
    if desire_flag:
        signal_type = "desire"
    elif repetition_flag:
        signal_type = "repetition"
    elif contains_any(text, FRICTION_KEYWORDS):
        signal_type = "friction"

    if tag_hint == "desire":
        desire_flag = True
        signal_type = "desire"
    elif tag_hint == "repetition":
        repetition_flag = True
        if signal_type == "life":
            signal_type = "repetition"
    elif tag_hint == "friction" and signal_type == "life":
        signal_type = "friction"

    return asdict(ClassifiedSignal(
        signal_type=signal_type,
        scene_type=detect_scene_type(text),
        friction_type=detect_friction_type(text),
        repetition_flag=repetition_flag,
        desire_flag=desire_flag,
        emotion_strength=detect_emotion_strength(text),
    ))
