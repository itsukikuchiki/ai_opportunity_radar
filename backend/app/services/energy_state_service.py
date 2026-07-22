from __future__ import annotations

from collections.abc import Iterable, Mapping
from typing import Any


ENERGY_STATE_KEYS = (
    "draining",
    "steady",
    "ease",
    "recovery",
    "boundary_buffer",
)


def classify_signal_energy_state(
    *,
    source_type: str | None = None,
    raw_payload: Mapping[str, Any] | None = None,
    energy_load: str | None = None,
    friction: str | None = None,
    positive_signal: str | None = None,
    linked_life_chain_stage: Mapping[str, Any] | Iterable[Any] | None = None,
    content: str | None = None,
) -> str:
    """Project one Signal into one exhaustive Weekly energy state.

    Explicit user input and legacy explicit effects are authoritative. The
    semantic fallback is deterministic: boundary/buffer, recovery, draining,
    ease, then steady. `steady` is the neutral fallback, so this function never
    emits an unknown/unclassified state.
    """

    payload = dict(raw_payload or {})
    normalized_source = _normalize(source_type)
    if normalized_source == "time_use" and not _is_completed_time_use(payload):
        return "steady"

    explicit_level = _energy_level(payload.get("energy_level"))
    if explicit_level is not None:
        if explicit_level == 0:
            return "draining"
        if explicit_level == 2:
            return "ease"
        return "steady"

    legacy_effect = _normalize(payload.get("energy_effect"))
    if legacy_effect == "draining":
        return "draining"
    if legacy_effect in {"neutral", "steady"}:
        return "steady"
    if legacy_effect in {"restoring", "recovery"}:
        return "recovery"
    if legacy_effect in {"ease", "resourced"}:
        return "ease"

    canonical_state = _normalize(payload.get("energy_state"))
    if canonical_state in ENERGY_STATE_KEYS:
        return canonical_state

    load = _normalize(energy_load)
    friction_value = _normalize(friction)
    positive = _normalize(positive_signal)
    text = _normalize(content)
    stages = _stage_values(linked_life_chain_stage)

    has_boundary_buffer = (
        _contains_any(load, ("boundary_buffer", "buffer"))
        or _contains_any(
            friction_value,
            (
                "boundary",
                "self_boundary",
                "boundary_load",
                "overcommit",
                "capacity_limit",
            ),
        )
        or bool(
            stages
            & {
                "boundary",
                "boundary_load",
                "buffer",
                "boundary_buffer",
            }
        )
        or _contains_any(
            text,
            (
                "留出余地",
                "留一点余地",
                "留了余地",
                "留出空间",
                "留了空间",
                "留出缓冲",
                "留了缓冲",
                "设了边界",
                "守住边界",
                "拒绝了",
                "说了不",
                "made room",
                "left room",
                "left a buffer",
                "set a boundary",
                "said no",
                "余白を残",
                "境界を守",
                "断った",
            ),
        )
    )
    if has_boundary_buffer:
        return "boundary_buffer"

    has_recovery = (
        _contains_any(load, ("restore", "restoring", "restorative", "recovery"))
        or "recovery" in stages
        or _contains_any(
            text,
            (
                "恢复了一点",
                "恢复过来",
                "缓过来",
                "补回精力",
                "休息后",
                "散步后",
                "睡了一觉",
                "充上电",
                "recovered",
                "felt restored",
                "after resting",
                "after a walk",
                "回復した",
                "休んだ後",
                "散歩の後",
            ),
        )
    )
    if has_recovery:
        return "recovery"

    has_draining = (
        _contains_any(load, ("drain", "draining", "high_drain", "exhaust"))
        or "energy_drain" in stages
        or _contains_any(
            text,
            (
                "很耗力",
                "有点耗力",
                "特别消耗",
                "精疲力尽",
                "很累",
                "疲惫",
                "exhausted",
                "draining",
                "worn out",
                "疲れた",
                "消耗した",
            ),
        )
    )
    if has_draining:
        return "draining"

    has_ease = (
        _contains_any(load, ("ease", "easy", "light", "resourced"))
        or bool(positive)
        or _contains_any(
            text,
            (
                "有余力",
                "很轻松",
                "比较轻松",
                "很顺畅",
                "精力很足",
                "状态很好",
                "felt easy",
                "felt light",
                "had energy left",
                "went smoothly",
                "余力がある",
                "楽だった",
                "順調だった",
            ),
        )
    )
    if has_ease:
        return "ease"

    return "steady"


def _normalize(value: Any) -> str:
    return str(value or "").strip().lower()


def _energy_level(value: Any) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        level = value
    elif isinstance(value, float) and value.is_integer():
        level = int(value)
    else:
        try:
            level = int(str(value).strip())
        except (TypeError, ValueError):
            return None
    return level if level in {0, 1, 2} else None


def _is_completed_time_use(payload: Mapping[str, Any]) -> bool:
    status = _normalize(payload.get("record_status"))
    if status in {"completed", "occurred", "actual"}:
        return True
    schema_version = payload.get("schema_version", 1)
    try:
        schema_version = int(schema_version)
    except (TypeError, ValueError):
        schema_version = 1
    return (
        not status
        and schema_version < 2
        and _normalize(payload.get("energy_effect"))
        in {"draining", "neutral", "restoring"}
    )


def _stage_values(
    value: Mapping[str, Any] | Iterable[Any] | None,
) -> set[str]:
    if isinstance(value, Mapping):
        value = value.get("stages", ())
    if isinstance(value, str):
        value = (value,)
    if value is None:
        return set()
    return {_normalize(item) for item in value if _normalize(item)}


def _contains_any(value: str, needles: Iterable[str]) -> bool:
    return any(needle in value for needle in needles)
