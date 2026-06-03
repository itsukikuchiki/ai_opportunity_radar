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
                "signal_parser",
                "today_high_quality_reply",
            }
            assert any(log.fallback_used for log in logs)
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_free_quota_exceeded_uses_fallback_without_losing_input():
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

            replies = []
            for index in range(4):
                result = service.submit_capture(
                    user_id="phase3-quota",
                    content=f"今天第 {index} 条记录，还是有点烦",
                    input_mode="quick_capture",
                    language="zh-Hans",
                    timezone_name="Asia/Tokyo",
                )
                replies.append(result.acknowledgement)

            cards = db.scalars(
                select(SignalCard).where(SignalCard.user_id == "phase3-quota")
            ).all()
            assert len(cards) == 4
            assert any(card.metadata_json.get("quota_decision") == "quota_exceeded" for card in cards)
            assert all(card.raw_text for card in cards)

            counter = db.scalars(
                select(UsageCounter).where(
                    UsageCounter.user_id == "phase3-quota",
                    UsageCounter.feature_key == "today_high_quality_reply",
                )
            ).one()
            assert counter.count == 3

            exceeded = db.scalars(
                select(QuotaGateEvent).where(QuotaGateEvent.decision == "quota_exceeded")
            ).all()
            assert len(exceeded) == 1
            assert "保存" in replies[-1]
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
