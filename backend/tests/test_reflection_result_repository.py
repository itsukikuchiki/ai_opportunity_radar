from datetime import date
from importlib import import_module, reload

from sqlalchemy import select

from test_capture_service_integration import _prepare_test_db


def test_weekly_upsert_writes_current_reflection_result():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        reload(import_module("app.repositories.reflection_result_repository"))
        reload(import_module("app.repositories.pipeline_run_repository"))
        reload(import_module("app.repositories.weekly_repository"))

        from app.models import PipelineRun, ReflectionResult, User
        from app.repositories.weekly_repository import WeeklyRepository

        db = SessionLocal()
        try:
            db.add(User(id="reflection-user"))
            db.flush()

            repo = WeeklyRepository(db)
            repo.upsert(
                "reflection-user",
                date(2026, 7, 6),
                {
                    "week_end": date(2026, 7, 12),
                    "status": "ready",
                    "key_insight": "这周最明显的是能量波动。",
                    "patterns": [{"name": "会议后更累"}],
                    "frictions": [{"name": "恢复时间不足"}],
                    "best_action": "把实验强度调轻一点。",
                    "opportunity_snapshot": {"energy_budget": "low"},
                    "source_hash": "weekly-source-v1",
                },
            )

            rows = db.scalars(select(ReflectionResult)).all()
            pipeline_runs = db.scalars(select(PipelineRun)).all()
            assert len(rows) == 1
            assert len(pipeline_runs) == 1
            assert rows[0].source_type == "weekly_snapshot"
            assert rows[0].source_id == "2026-07-06"
            assert rows[0].reflection_type == "reflect"
            assert rows[0].ai_level == "L3"
            assert rows[0].status == "generated"
            assert rows[0].source_hash == "weekly-source-v1"
            assert rows[0].pipeline_version == "v4_p0_05"
            assert rows[0].content_json["best_action"] == "把实验强度调轻一点。"
            assert pipeline_runs[0].pipeline_type == "weekly_aggregation"
            assert pipeline_runs[0].source_type == "weekly_snapshot"
            assert pipeline_runs[0].source_id == "2026-07-06"
            assert pipeline_runs[0].status == "completed"
            assert pipeline_runs[0].input_hash == "weekly-source-v1"

            repo.upsert(
                "reflection-user",
                date(2026, 7, 6),
                {
                    "week_end": date(2026, 7, 12),
                    "status": "ready",
                    "key_insight": "更新后的周复盘。",
                    "patterns": [],
                    "frictions": [],
                    "best_action": "继续轻量实验。",
                    "opportunity_snapshot": None,
                    "source_hash": "weekly-source-v2",
                },
            )

            rows = db.scalars(
                select(ReflectionResult).order_by(ReflectionResult.generated_at)
            ).all()
            pipeline_runs = db.scalars(select(PipelineRun)).all()
            assert len(rows) == 2
            assert len(pipeline_runs) == 2
            assert {row.status for row in rows} == {"superseded", "generated"}
            latest = next(row for row in rows if row.status == "generated")
            old = next(row for row in rows if row.status == "superseded")
            assert old.superseded_by == latest.id
            assert latest.content_json["key_insight"] == "更新后的周复盘。"
            assert all(run.status == "completed" for run in pipeline_runs)
        finally:
            db.close()
    finally:
        tmpdir.cleanup()


def test_prompt_model_rollout_marks_old_reflections_stale_without_dirtying_snapshot():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        reload(import_module("app.repositories.reflection_result_repository"))
        reload(import_module("app.repositories.pipeline_run_repository"))
        reload(import_module("app.repositories.weekly_repository"))

        from app.models import ReflectionResult, ReflectionVersionRegistry, User, WeeklyInsight
        from app.repositories.reflection_result_repository import ReflectionResultRepository
        from app.repositories.weekly_repository import WeeklyRepository

        db = SessionLocal()
        try:
            db.add(User(id="rollout-user"))
            db.flush()

            weekly_repo = WeeklyRepository(db)
            weekly_repo.upsert(
                "rollout-user",
                date(2026, 7, 6),
                {
                    "week_end": date(2026, 7, 12),
                    "status": "ready",
                    "key_insight": "这周需要轻一点。",
                    "patterns": [],
                    "frictions": [],
                    "best_action": "轻量实验。",
                    "opportunity_snapshot": {"energy_budget": "low"},
                    "source_hash": "weekly-source-v1",
                },
            )

            repository = ReflectionResultRepository(db)
            current = repository.get_latest_current(
                user_id="rollout-user",
                source_type="weekly_snapshot",
                source_id="2026-07-06",
                reflection_type="reflect",
                ai_level="L3",
            )
            assert current is not None
            assert current.prompt_version == "prompt_reflect_v1"
            assert current.model_version == "model_reflect_default"

            stale_count = repository.rollout_versions(
                source_type="weekly_snapshot",
                reflection_type="reflect",
                ai_level="L3",
                prompt_version="weekly_reflect_prompt_v2",
                model_version="gpt-6-reflect",
                reason="weekly_reflect_rollout_v2",
            )
            assert stale_count == 1

            old = db.get(ReflectionResult, current.id)
            assert old.is_stale == 1
            assert old.dirty == 0
            assert old.stale_reason == "weekly_reflect_rollout_v2"
            assert old.invalidated_at is not None
            assert db.get(WeeklyInsight, "weekly_rollout-user_2026-07-06") is not None
            assert db.get(WeeklyInsight, "weekly_rollout-user_2026-07-06").status == "ready"

            registry = db.scalars(select(ReflectionVersionRegistry)).one()
            assert registry.prompt_version == "weekly_reflect_prompt_v2"
            assert registry.model_version == "gpt-6-reflect"

            assert repository.get_latest_current(
                user_id="rollout-user",
                source_type="weekly_snapshot",
                source_id="2026-07-06",
                reflection_type="reflect",
                ai_level="L3",
            ) is None

            regenerated = repository.save_current(
                user_id="rollout-user",
                source_type="weekly_snapshot",
                source_id="2026-07-06",
                reflection_type="reflect",
                ai_level="L3",
                content={"key_insight": "新 prompt 重新生成。"},
                source_hash="weekly-source-v1",
            )
            assert regenerated.prompt_version == "weekly_reflect_prompt_v2"
            assert regenerated.model_version == "gpt-6-reflect"
            assert regenerated.pipeline_version == "v4_p0_05"

            latest = repository.get_latest_current(
                user_id="rollout-user",
                source_type="weekly_snapshot",
                source_id="2026-07-06",
                reflection_type="reflect",
                ai_level="L3",
            )
            assert latest.id == regenerated.id
            assert latest.content_json["key_insight"] == "新 prompt 重新生成。"
        finally:
            db.close()
    finally:
        tmpdir.cleanup()
