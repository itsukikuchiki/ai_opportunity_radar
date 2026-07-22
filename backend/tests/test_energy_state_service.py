from app.services.energy_state_service import (
    ENERGY_STATE_KEYS,
    classify_signal_energy_state,
)


def test_explicit_energy_level_is_authoritative():
    assert classify_signal_energy_state(
        raw_payload={"energy_level": 0},
        energy_load="restoring",
    ) == "draining"
    assert classify_signal_energy_state(
        raw_payload={"energy_level": 1},
        friction="boundary",
    ) == "steady"
    assert classify_signal_energy_state(
        raw_payload={"energy_level": 2},
        energy_load="draining",
    ) == "ease"


def test_legacy_effect_maps_to_five_state_contract():
    assert classify_signal_energy_state(
        raw_payload={"energy_effect": "draining"}
    ) == "draining"
    assert classify_signal_energy_state(
        raw_payload={"energy_effect": "neutral"}
    ) == "steady"
    assert classify_signal_energy_state(
        raw_payload={"energy_effect": "restoring"}
    ) == "recovery"


def test_semantic_precedence_and_exhaustive_fallback():
    cases = [
        (
            {
                "friction": "boundary_load",
                "energy_load": "restoring",
                "content": "很累，但给晚上留了缓冲",
            },
            "boundary_buffer",
        ),
        (
            {
                "energy_load": "restoring",
                "content": "散步后恢复了一点",
            },
            "recovery",
        ),
        (
            {"energy_load": "draining", "positive_signal": "support"},
            "draining",
        ),
        ({"content": "今天做事很顺畅，还有余力"}, "ease"),
        ({"content": "今天记下了一件普通的事"}, "steady"),
        (
            {
                "energy_load": "mystery",
                "raw_payload": {"energy_state": "unclassified"},
            },
            "steady",
        ),
    ]

    states = []
    for values, expected in cases:
        state = classify_signal_energy_state(**values)
        states.append(state)
        assert state == expected

    assert set(states).issubset(set(ENERGY_STATE_KEYS))
    assert "unknown" not in states


def test_planned_time_use_is_steady_until_it_becomes_observed():
    assert classify_signal_energy_state(
        source_type="time_use",
        raw_payload={
            "schema_version": 2,
            "record_status": "planned",
            "energy_level": 2,
            "energy_effect": "restoring",
        },
    ) == "steady"
    assert classify_signal_energy_state(
        source_type="time_use",
        raw_payload={
            "schema_version": 2,
            "record_status": "completed",
            "energy_level": 2,
        },
    ) == "ease"
