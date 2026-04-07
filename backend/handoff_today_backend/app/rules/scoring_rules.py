def clamp_score(value: float, minimum: float = 0.0, maximum: float = 5.0) -> float:
    return max(minimum, min(maximum, value))


def derive_repeatability_score(pattern: dict) -> float:
    freq_7d = pattern.get("frequency_7d", 0)
    freq_30d = pattern.get("frequency_30d", 0)
    stability = float(pattern.get("stability_score", 0))
    score = 1.0
    if freq_7d >= 2:
        score += 1.0
    if freq_7d >= 4:
        score += 1.0
    if freq_30d >= 6:
        score += 1.0
    if stability >= 0.7:
        score += 1.0
    return clamp_score(score)


def derive_pain_score(friction: dict) -> float:
    severity = float(friction.get("severity_score", 0))
    freq_7d = friction.get("frequency_7d", 0)
    score = 1.0 + severity * 2.5
    if freq_7d >= 2:
        score += 0.75
    if freq_7d >= 4:
        score += 0.75
    return clamp_score(score)


def derive_desire_score(desire: dict | None) -> float:
    if not desire:
        return 1.5
    mention_count = desire.get("mention_count", 0)
    priority = float(desire.get("priority_score", 0))
    return clamp_score(1.0 + min(mention_count, 3) * 0.8 + priority * 1.2)


def calculate_opportunity_score(pattern: dict, friction: dict, desire: dict | None = None, clarity_score: float = 3.0, ai_fit_score: float = 3.0) -> dict:
    repeatability = derive_repeatability_score(pattern)
    pain = derive_pain_score(friction)
    desire_score = derive_desire_score(desire)
    total = repeatability * 0.25 + pain * 0.25 + clarity_score * 0.20 + desire_score * 0.15 + ai_fit_score * 0.15
    return {
        "repeatability": round(repeatability, 2),
        "pain": round(pain, 2),
        "clarity": round(clamp_score(clarity_score), 2),
        "desire": round(desire_score, 2),
        "ai_fit": round(clamp_score(ai_fit_score), 2),
        "total": round(total, 2),
    }


def map_maturity(score: dict) -> str:
    total = score["total"]
    if score["clarity"] <= 2 or score["repeatability"] <= 2 or score["ai_fit"] <= 2:
        return "observing"
    if total <= 2.0:
        return "observing"
    if total <= 3.0:
        return "emerging"
    if total <= 4.0:
        return "pilot_ready"
    return "build_ready"
