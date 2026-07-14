from datetime import datetime, timezone
from importlib import import_module, reload

from sqlalchemy import select, func

from test_capture_service_integration import _patch_demo_user, _prepare_test_db


def _reload_phase3_modules():
    module_names = [
        "app.repositories.capture_repository",
        "app.services.capture_service",
        "app.services.usage_service",
        "app.services.classification_service",
    ]
    return [reload(import_module(name)) for name in module_names]


class FailingParserAndReply:
    def classify_capture(self, content, tag_hint=None):  # noqa: ANN001
        raise RuntimeError("parser offline")

    def generate_acknowledgement(self, *args, **kwargs):  # noqa: ANN002, ANN003
        raise RuntimeError("reply offline")


def test_save_first_keeps_signal_card_when_parser_and_reply_fail():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import Capture, ModelUsageLog, QuotaGateEvent, RawMemory, SignalCard
        from app.repositories.capture_repository import CaptureRepository
        from app.services.capture_service import CaptureService
        from app.services.usage_service import UsageService

        db = SessionLocal()
        try:
            service = CaptureService(
                CaptureRepository(db),
                FailingParserAndReply(),
                UsageService(db),
            )

            result = service.submit_capture(
                user_id="phase3-save-first",
                content="今天被打断很多次，很烦",
                input_mode="quick_capture",
                language="zh-Hans",
                timezone_name="Asia/Tokyo",
            )

            assert "保存" in result.acknowledgement
            assert db.scalar(select(func.count()).select_from(Capture)) == 1
            assert db.scalar(select(func.count()).select_from(RawMemory)) == 1
            assert db.scalar(select(func.count()).select_from(SignalCard)) == 1

            card = db.scalars(select(SignalCard)).one()
            assert card.raw_text == "今天被打断很多次，很烦"
            assert card.ai_reply == result.acknowledgement
            assert card.metadata_json["parser_status"] == "failed"
            assert card.metadata_json["ai_reply_status"] == "fallback"
            assert card.user_confirmation == "unconfirmed"
            assert card.privacy_level == "private"

            quota_events = db.scalars(select(QuotaGateEvent)).all()
            assert len(quota_events) == 1
            assert quota_events[0].decision == "allowed"

            logs = db.scalars(select(ModelUsageLog)).all()
            assert {log.feature_key for log in logs} == {
                "l1_assist_daily_flow",
                "l1_attune_dialogue",
            }
            assert any(log.fallback_used for log in logs)
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_free_l1_attune_keeps_daily_recording_flow_open():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import QuotaGateEvent, SignalCard, UsageCounter
        from app.repositories.capture_repository import CaptureRepository
        from app.services.capture_service import CaptureService
        from app.services.classification_service import ClassificationService
        from app.services.usage_service import UsageService

        db = SessionLocal()
        try:
            service = CaptureService(
                CaptureRepository(db),
                ClassificationService(),
                UsageService(db),
            )

            for index in range(4):
                service.submit_capture(
                    user_id="phase3-quota",
                    content=f"今天第 {index} 条记录，还是有点烦",
                    input_mode="quick_capture",
                    language="zh-Hans",
                    timezone_name="Asia/Tokyo",
                )

            cards = db.scalars(
                select(SignalCard).where(SignalCard.user_id == "phase3-quota")
            ).all()
            assert len(cards) == 4
            assert all(card.metadata_json.get("quota_decision") == "allowed" for card in cards)
            assert all(card.raw_text for card in cards)

            counter = db.scalars(
                select(UsageCounter).where(
                    UsageCounter.user_id == "phase3-quota",
                    UsageCounter.feature_key == "l1_attune_dialogue",
                )
            ).one()
            assert counter.count == 4

            exceeded = db.scalars(
                select(QuotaGateEvent).where(QuotaGateEvent.decision == "quota_exceeded")
            ).all()
            assert len(exceeded) == 0
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_legacy_today_records_migrate_to_signal_cards_and_preserve_ai_reply():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import Capture, RawMemory, SignalCard
        from app.repositories.capture_repository import CaptureRepository
        from app.repositories.core_repository import ensure_demo_user

        db = SessionLocal()
        try:
            ensure_demo_user(db, "phase3-migration")
            created_at = datetime(2026, 5, 1, 15, 30, tzinfo=timezone.utc)
            capture = Capture(
                id="cap_legacy_1",
                user_id="phase3-migration",
                content="旧记录：今天很累",
                input_mode="quick_capture",
                tag_hint=None,
                created_at=created_at,
            )
            raw = RawMemory(
                id="raw_legacy_1",
                user_id="phase3-migration",
                capture_id="cap_legacy_1",
                source="capture",
                content="旧记录：今天很累",
                signal_type="friction",
                scene_type="work",
                friction_type="execution",
                emotion_strength="high",
                repetition_flag=False,
                desire_flag=False,
                related_pattern_id=None,
                related_friction_id=None,
                metadata_json={"acknowledgement": "旧 AI 回复必须保留"},
                created_at=created_at,
            )
            db.add(capture)
            db.add(raw)
            db.commit()

            before_raw = db.scalar(select(func.count()).select_from(RawMemory))
            before_cards = db.scalar(select(func.count()).select_from(SignalCard))

            result = CaptureRepository(db).migrate_legacy_signal_cards(
                user_id="phase3-migration",
                commit=True,
            )

            after_cards = db.scalar(select(func.count()).select_from(SignalCard))
            card = db.scalars(select(SignalCard)).one()

            assert before_raw == 1
            assert before_cards == 0
            assert after_cards == 1
            assert result["created"] == 1
            assert card.raw_text == "旧记录：今天很累"
            assert card.ai_reply == "旧 AI 回复必须保留"
            assert card.is_legacy is True
            assert card.migration_status == "migrated_partial"
            assert card.user_confirmation == "unconfirmed"
            assert card.metadata_json["legacy_source_id"] == "raw_legacy_1"

            second = CaptureRepository(db).migrate_legacy_signal_cards(
                user_id="phase3-migration",
                commit=True,
            )
            assert second["created"] == 0
            assert db.scalar(select(func.count()).select_from(SignalCard)) == 1
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_signal_card_confirmation_writes_user_correction():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import SignalCard
        from app.repositories.capture_repository import CaptureRepository
        from app.services.capture_service import CaptureService
        from app.services.classification_service import ClassificationService
        from app.services.usage_service import UsageService

        db = SessionLocal()
        try:
            service = CaptureService(
                CaptureRepository(db),
                ClassificationService(),
                UsageService(db),
            )
            service.submit_capture(
                user_id="phase3-confirm",
                content="今天沟通来回确认，很消耗",
                language="zh-Hans",
                timezone_name="Asia/Tokyo",
            )
            card = db.scalars(select(SignalCard)).one()

            updated = CaptureRepository(db).update_signal_card_confirmation(
                user_id="phase3-confirm",
                signal_card_id=card.id,
                user_confirmation="edited",
                user_correction={"friction": "coordination", "note": "更像沟通消耗"},
                commit=True,
            )

            assert updated is not None
            assert updated.user_confirmation == "edited"
            assert updated.user_correction_json["friction"] == "coordination"
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_signal_card_processing_state_and_analysis_policy_are_split():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import SignalAnalysisPolicy, SignalProcessingState
        from app.repositories.capture_repository import CaptureRepository
        from app.services.capture_service import CaptureService
        from app.services.classification_service import ClassificationService
        from app.services.usage_service import UsageService

        db = SessionLocal()
        try:
            service = CaptureService(
                CaptureRepository(db),
                ClassificationService(),
                UsageService(db),
            )
            result = service.submit_capture(
                user_id="phase3-split-state",
                content="今天被打断很多次，很烦",
                language="zh-Hans",
                timezone_name="Asia/Tokyo",
            )
            signal_card_id = result.recent_signals[0].signal_card_id

            state = db.get(SignalProcessingState, signal_card_id)
            policy = db.get(SignalAnalysisPolicy, signal_card_id)

            assert state is not None
            assert state.sync_status == "synced"
            assert state.daily_status == "not_started"
            assert state.processing_version == "v4_p0_02"
            assert policy is not None
            assert policy.privacy_level == "private"
            assert policy.inaccurate is False

            CaptureRepository(db).update_signal_card_confirmation(
                user_id="phase3-split-state",
                signal_card_id=signal_card_id,
                user_confirmation="inaccurate",
                user_correction={"note": "不是有效记录"},
                commit=True,
            )
            updated_policy = db.get(SignalAnalysisPolicy, signal_card_id)
            assert updated_policy.inaccurate is True
            assert updated_policy.exclusion_reason == "inaccurate"
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_signal_card_parent_is_flushed_before_split_child_rows():
    """Keep strict PostgreSQL FK ordering without relying on ORM relationships."""
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from sqlalchemy import select

        from app.models import SignalCard
        from app.repositories.capture_repository import CaptureRepository

        db = SessionLocal()
        try:
            repository = CaptureRepository(db)
            original = repository._ensure_processing_state

            def assert_parent_persisted(*, signal_card_id: str, **kwargs):
                persisted_id = db.connection().execute(
                    select(SignalCard.id).where(SignalCard.id == signal_card_id)
                ).scalar_one_or_none()
                assert persisted_id == signal_card_id
                return original(signal_card_id=signal_card_id, **kwargs)

            repository._ensure_processing_state = assert_parent_persisted
            created = repository.create_capture_skeleton(
                user_id="strict-fk-order-user",
                content="先保存父信号，再创建拆分状态。",
                client_id="strict-fk-order-client",
            )

            assert created["signal_card_id"].startswith("sig_")
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_recent_read_does_not_reset_existing_processing_state_or_policy():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import SignalAnalysisPolicy, SignalProcessingState
        from app.repositories.capture_repository import CaptureRepository

        db = SessionLocal()
        try:
            repository = CaptureRepository(db)
            created = repository.create_capture_skeleton(
                user_id="phase3-read-preserves-state",
                content="正在处理的信号不能被读取动作重置。",
            )
            signal_id = created["signal_card_id"]
            state = db.get(SignalProcessingState, signal_id)
            policy = db.get(SignalAnalysisPolicy, signal_id)
            state.sync_status = "failed"
            state.daily_status = "processing"
            state.weekly_status = "failed"
            state.journey_status = "processing"
            state.last_error = "transient_pipeline_failure"
            state.processing_version = "future_pipeline_v9"
            policy.requires_user_confirmation = True
            policy.exclusion_reason = "manual_review"
            db.commit()

            cards = repository.list_recent_signal_cards(
                user_id="phase3-read-preserves-state",
                limit=10,
            )
            db.refresh(state)
            db.refresh(policy)

            assert [card.id for card in cards] == [signal_id]
            assert state.sync_status == "failed"
            assert state.daily_status == "processing"
            assert state.weekly_status == "failed"
            assert state.journey_status == "processing"
            assert state.last_error == "transient_pipeline_failure"
            assert state.processing_version == "future_pipeline_v9"
            assert policy.requires_user_confirmation is True
            assert policy.exclusion_reason == "manual_review"
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_client_id_makes_capture_submit_idempotent():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import Capture, RawMemory, SignalCard
        from app.repositories.capture_repository import CaptureRepository

        db = SessionLocal()
        try:
            repo = CaptureRepository(db)
            first = repo.create_capture_skeleton(
                user_id="phase3-sync",
                content="断网重试不应该重复",
                input_mode="quick_capture",
                language="zh-Hans",
                timezone_name="Asia/Tokyo",
                client_id="client-draft-1",
                commit=True,
            )
            second = repo.create_capture_skeleton(
                user_id="phase3-sync",
                content="断网重试不应该重复",
                input_mode="quick_capture",
                language="zh-Hans",
                timezone_name="Asia/Tokyo",
                client_id="client-draft-1",
                commit=True,
            )

            assert first["signal_card_id"] == second["signal_card_id"]
            assert db.scalar(select(func.count()).select_from(SignalCard)) == 1
            assert db.scalar(select(func.count()).select_from(Capture)) == 1
            assert db.scalar(select(func.count()).select_from(RawMemory)) == 1

            card = db.scalars(select(SignalCard)).one()
            assert card.client_id == "client-draft-1"
            assert card.server_id == card.id
            assert card.raw_payload_json["client_id"] == "client-draft-1"
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_signal_card_soft_delete_tombstone_propagates_and_restore_is_explicit():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import (
            ExperimentCandidate,
            ReflectionResult,
            SignalAnalysisPolicy,
            SignalCard,
            SignalProcessingState,
            TraceLink,
            WeeklyInsight,
        )
        from app.repositories.capture_repository import CaptureRepository
        from app.services.capture_service import CaptureService
        from app.services.classification_service import ClassificationService
        from app.services.usage_service import UsageService

        db = SessionLocal()
        try:
            service = CaptureService(
                CaptureRepository(db),
                ClassificationService(),
                UsageService(db),
            )
            result = service.submit_capture(
                user_id="phase3-soft-delete",
                content="会议后很累，需要恢复",
                language="zh-Hans",
                timezone_name="Asia/Tokyo",
                client_id="client-soft-delete-1",
            )
            signal_card_id = result.recent_signals[0].signal_card_id
            card = db.get(SignalCard, signal_card_id)

            weekly = WeeklyInsight(
                id="weekly_soft_delete",
                user_id="phase3-soft-delete",
                week_start=card.local_date,
                week_end=card.local_date,
                status="available",
                key_insight="恢复需求更清楚",
                top_patterns_json=[],
                top_frictions_json=[],
                best_action="留一点恢复时间",
                opportunity_snapshot_json={},
                chart_data_json=[],
            )
            reflection = ReflectionResult(
                id="refl_soft_delete",
                user_id="phase3-soft-delete",
                source_type="weekly_snapshot",
                source_id=card.local_date.isoformat(),
                reflection_type="reflect",
                ai_level="L3",
                content_json={"key_insight": "恢复需求更清楚"},
                status="generated",
            )
            trace = TraceLink(
                id="trace_soft_delete",
                user_id="phase3-soft-delete",
                source_type="weekly_snapshot",
                source_id=card.local_date.isoformat(),
                target_type="signal_card",
                target_id=signal_card_id,
                relation_type="uses_trace",
                status="active",
                metadata_json={},
            )
            candidate = ExperimentCandidate(
                id="cand_soft_delete",
                user_id="phase3-soft-delete",
                source_type="weekly_reflection",
                source_id=card.local_date.isoformat(),
                source_week_start=card.local_date,
                source_week_end=card.local_date,
                title="留一点会议恢复",
                hypothesis="会议后恢复可能更省力",
                suggested_action="会议后留 10 分钟",
                linked_signal_card_ids=[signal_card_id],
                linked_observation_ids=[],
                status="generated",
                confidence_level="medium",
                metadata_json={},
            )
            db.add_all([weekly, reflection, trace, candidate])
            db.commit()

            deleted = CaptureRepository(db).soft_delete_signal_card(
                user_id="phase3-soft-delete",
                signal_card_id=signal_card_id,
                reason="user_deleted",
                commit=True,
            )

            assert deleted is not None
            assert deleted.deleted_at is not None
            assert deleted.tombstone_version == 1
            assert service.list_recent_signal_cards(
                user_id="phase3-soft-delete",
                limit=10,
            ) == []
            assert db.get(TraceLink, "trace_soft_delete").status == "inactive"
            stale_reflection = db.get(ReflectionResult, "refl_soft_delete")
            assert stale_reflection.is_stale == 1
            assert stale_reflection.dirty == 1
            assert stale_reflection.stale_reason == "signal_deleted"
            assert db.get(WeeklyInsight, "weekly_soft_delete").status == "stale"
            stale_candidate = db.get(ExperimentCandidate, "cand_soft_delete")
            assert stale_candidate.status == "stale"
            assert stale_candidate.metadata_json["stale_reason"] == "signal_deleted"
            state = db.get(SignalProcessingState, signal_card_id)
            policy = db.get(SignalAnalysisPolicy, signal_card_id)
            assert state.sync_status == "deleted"
            assert state.weekly_status == "excluded"
            assert policy.do_not_analyze is True
            assert policy.exclusion_reason == "signal_deleted"

            replay = service.submit_capture(
                user_id="phase3-soft-delete",
                content="会议后很累，需要恢复",
                language="zh-Hans",
                timezone_name="Asia/Tokyo",
                client_id="client-soft-delete-1",
            )
            assert replay.recent_signals == []
            assert db.get(SignalCard, signal_card_id).deleted_at is not None

            restored = CaptureRepository(db).restore_signal_card(
                user_id="phase3-soft-delete",
                signal_card_id=signal_card_id,
                commit=True,
            )
            assert restored is not None
            assert restored.deleted_at is None
            assert restored.restored_at is not None
            assert db.get(TraceLink, "trace_soft_delete").status == "active"
            assert len(service.list_recent_signal_cards(
                user_id="phase3-soft-delete",
                limit=10,
            )) == 1
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_memory_summary_reads_signal_cards_as_primary_fact_source():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import RawMemory, SignalCard
        from app.repositories.memory_repository import MemoryRepository

        db = SessionLocal()
        try:
            created_at = datetime(2026, 5, 1, 15, 30, tzinfo=timezone.utc)
            card = SignalCard(
                id="sig_primary_fact",
                user_id="phase3-primary-source",
                capture_id=None,
                raw_memory_id=None,
                source_type="text",
                raw_text="今天开会很多，很消耗",
                raw_payload_json={},
                ai_reply="已保存。",
                created_at=created_at,
                local_date=created_at.date(),
                timezone="Asia/Tokyo",
                language="zh-Hans",
                emotion="friction",
                intensity=4,
                scene="work",
                friction="coordination",
                positive_signal=None,
                energy_load="draining",
                linked_life_chain_stage={},
                confidence_score=0.8,
                user_confirmation="unconfirmed",
                user_correction_json={},
                included_in_summary=False,
                included_in_weekly=False,
                included_in_journey=False,
                linked_experiment_id=None,
                parser_version="test",
                model_used=None,
                prompt_version=None,
                token_usage_json={},
                privacy_level="private",
                schema_version=1,
                is_legacy=False,
                migration_status="native",
                metadata_json={},
            )
            db.add(card)
            db.commit()

            repo = MemoryRepository(db)
            summary = repo.raw_summary(
                "phase3-primary-source",
                created_at.date(),
                created_at.date(),
            )

            assert db.scalar(select(func.count()).select_from(RawMemory)) == 0
            assert repo.get_first_signal_date("phase3-primary-source") == created_at.date()
            assert summary["signal_count"] == 1
            assert summary["top_scene_types"] == ["work"]
            assert summary["top_friction_types"] == ["coordination"]
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_memory_summary_uses_shared_eligibility_policy():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import SignalAnalysisPolicy, SignalCard, SignalProcessingState
        from app.repositories.memory_repository import MemoryRepository

        db = SessionLocal()
        try:
            day = datetime(2026, 5, 2, 10, tzinfo=timezone.utc)

            def add_card(card_id, text, privacy="private", confirmation="unconfirmed"):
                card = SignalCard(
                    id=card_id,
                    user_id="phase3-eligibility-summary",
                    capture_id=None,
                    raw_memory_id=None,
                    source_type="text",
                    raw_text=text,
                    raw_payload_json={},
                    ai_reply="已保存。",
                    created_at=day,
                    local_date=day.date(),
                    timezone="Asia/Tokyo",
                    language="zh-Hans",
                    emotion="friction",
                    intensity=4,
                    scene="work",
                    friction="coordination",
                    positive_signal=None,
                    energy_load="draining",
                    linked_life_chain_stage={},
                    confidence_score=0.8,
                    user_confirmation=confirmation,
                    user_correction_json={},
                    included_in_summary=False,
                    included_in_weekly=False,
                    included_in_journey=False,
                    linked_experiment_id=None,
                    parser_version="test",
                    model_used=None,
                    prompt_version=None,
                    token_usage_json={},
                    privacy_level=privacy,
                    schema_version=1,
                    is_legacy=False,
                    migration_status="native",
                    metadata_json={},
                )
                db.add(card)
                db.add(SignalProcessingState(signal_id=card_id, sync_status="synced"))
                db.add(
                    SignalAnalysisPolicy(
                        signal_id=card_id,
                        privacy_level=privacy,
                        do_not_analyze=privacy == "do_not_analyze",
                        inaccurate=confirmation == "inaccurate",
                    )
                )

            add_card("sig_used", "有效记录")
            add_card("sig_private", "不要分析", privacy="do_not_analyze")
            add_card("sig_bad", "不准确", confirmation="inaccurate")
            db.commit()

            summary = MemoryRepository(db).raw_summary(
                "phase3-eligibility-summary",
                day.date(),
                day.date(),
            )

            assert summary["signal_count"] == 1
            assert summary["top_scene_types"] == ["work"]
            assert summary["top_friction_types"] == ["coordination"]
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_model_usage_log_strips_raw_text_from_privacy_sensitive_metadata():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()
        _reload_phase3_modules()

        from app.models import ModelUsageLog
        from app.repositories.core_repository import ensure_demo_user
        from app.services.usage_service import UsageService

        db = SessionLocal()
        try:
            ensure_demo_user(db, "phase3-privacy")
            UsageService(db).log_model_usage(
                user_id="phase3-privacy",
                feature_key="signal_library_aggregate",
                model_used="local_rules",
                metadata={
                    "raw_text": "这句用户原文不能进共享分析",
                    "abstract_pattern": "attention_switching_fatigue",
                },
                commit=True,
            )
            log = db.scalars(select(ModelUsageLog)).one()
            assert "raw_text" not in log.metadata_json
            assert log.metadata_json["abstract_pattern"] == "attention_switching_fatigue"
        finally:
            db.close()
    finally:
        tmpdir.cleanup()
