from datetime import datetime, timezone
from types import SimpleNamespace

from app.services.signal_eligibility_service import (
    SignalEligibilityService,
    SignalEligibilityStage,
)


def _signal(**overrides):
    defaults = {
        "source_type": "text",
        "user_confirmation": "unconfirmed",
        "user_correction_json": {},
        "privacy_level": "private",
        "is_legacy": False,
        "metadata_json": {},
    }
    defaults.update(overrides)
    return SimpleNamespace(**defaults)


def test_excludes_sync_failed_privacy_and_inaccurate_signals():
    service = SignalEligibilityService()
    signal = _signal(
        user_confirmation="inaccurate",
        privacy_level="do_not_analyze",
        metadata_json={"sync_status": "failed"},
    )

    result = service.evaluate(signal, SignalEligibilityStage.WEEKLY)

    assert result.eligible is False
    assert result.policy_version == "v5_current_objects_only_1"
    assert result.reasons == ["sync_failed", "inaccurate", "do_not_analyze"]


def test_library_saved_requires_user_supplied_personal_context():
    service = SignalEligibilityService()
    unconfirmed = _signal(
        source_type="library_saved",
        user_confirmation="edited",
        user_correction_json={},
    )
    confirmed = _signal(
        source_type="library_saved",
        user_confirmation="supplemented",
        user_correction_json={"supplement_text": "这周晚饭后试一次"},
    )

    assert service.evaluate(unconfirmed, "weekly").reasons == ["library_unconfirmed"]
    assert service.is_eligible(confirmed, "weekly") is True


def test_ai_prediction_requires_user_confirmed_context():
    service = SignalEligibilityService()
    unconfirmed = _signal(
        source_type="ai_predicted",
        user_confirmation="unconfirmed",
    )
    confirmed = _signal(
        source_type="ai_predicted",
        user_confirmation="edited",
        user_correction_json={"edited_text": "我确认这是今天的主要消耗"},
    )

    assert service.evaluate(unconfirmed, "weekly").reasons == [
        "ai_prediction_unconfirmed"
    ]
    assert service.is_eligible(confirmed, "weekly") is True


def test_every_active_analysis_stage_excludes_legacy_references():
    service = SignalEligibilityService()
    legacy = _signal(is_legacy=True)

    for stage in SignalEligibilityStage:
        assert service.evaluate(legacy, stage).reasons == ["legacy_reference"]


def test_schedule_and_goal_sources_are_compatibility_only_even_without_flag():
    service = SignalEligibilityService()

    for source_type in [
        "calendar",
        "manual_schedule",
        "schedule_feedback",
        "goal",
        "goal_feedback",
    ]:
        for stage in SignalEligibilityStage:
            assert service.evaluate(
                _signal(source_type=source_type), stage
            ).reasons == ["legacy_reference"]


def test_time_use_is_a_current_signal_card_source():
    service = SignalEligibilityService()

    for stage in SignalEligibilityStage:
        assert service.is_eligible(_signal(source_type="time_use"), stage) is True


def test_deleted_signal_is_never_eligible_even_without_split_policy_rows():
    service = SignalEligibilityService()
    signal = _signal(deleted_at=datetime.now(timezone.utc))

    for stage in SignalEligibilityStage:
        assert service.evaluate(signal, stage).reasons == ["deleted"]


def test_reads_split_processing_state_and_analysis_policy():
    service = SignalEligibilityService()
    signal = _signal(
        user_confirmation="unconfirmed",
        privacy_level="private",
    )
    signal.processing_state = SimpleNamespace(
        sync_status="failed",
        sync_failed=True,
    )
    signal.analysis_policy = SimpleNamespace(
        privacy_level="do_not_analyze",
        inaccurate=True,
    )

    result = service.evaluate(signal, "weekly")

    assert result.eligible is False
    assert result.reasons == ["sync_failed", "inaccurate", "do_not_analyze"]
