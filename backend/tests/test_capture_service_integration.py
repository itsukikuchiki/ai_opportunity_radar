import os
import sys
import tempfile
from importlib import import_module, reload

from sqlalchemy import select, func


def _prepare_test_db():
    tmpdir = tempfile.TemporaryDirectory()
    db_path = os.path.join(tmpdir.name, "test_capture_service.db")
    os.environ["DATABASE_URL"] = f"sqlite:///{db_path}"

    # 1) 先让新的 DATABASE_URL 生效
    core_config = import_module("app.core.config")
    core_db = import_module("app.core.db")
    reload(core_config)
    reload(core_db)

    # 2) 关键：清掉已加载的 app.models 相关模块，避免旧 Base / 旧模型残留
    modules_to_clear = [
        name for name in list(sys.modules.keys())
        if name == "app.models" or name.startswith("app.models.")
    ]
    for name in modules_to_clear:
        sys.modules.pop(name, None)

    # 3) 重新导入 models，让所有 ORM 模型绑定到当前这套新的 Base
    import_module("app.models")

    # 4) 用当前 Base / engine 显式建表
    from app.core.db import Base, SessionLocal, engine
    Base.metadata.create_all(bind=engine)

    return tmpdir, SessionLocal


def _patch_demo_user():
    def _noop_ensure_demo_user(db, user_id):  # noqa: ANN001
        return None

    for module_name in [
        "app.repositories.core_repository",
        "app.repositories.capture_repository",
        "app.services.capture_service",
    ]:
        module = import_module(module_name)
        if hasattr(module, "ensure_demo_user"):
            setattr(module, "ensure_demo_user", _noop_ensure_demo_user)


def test_submit_capture_persists_capture_and_raw_memory():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()

        capture_repo_module = import_module("app.repositories.capture_repository")
        classification_module = import_module("app.services.classification_service")
        capture_service_module = import_module("app.services.capture_service")

        reload(capture_repo_module)
        reload(classification_module)
        reload(capture_service_module)

        from app.models.capture import Capture
        from app.models.raw_memory import RawMemory
        from app.repositories.capture_repository import CaptureRepository
        from app.services.capture_service import CaptureService
        from app.services.classification_service import ClassificationService

        db = SessionLocal()
        try:
            service = CaptureService(
                CaptureRepository(db),
                ClassificationService(),
            )

            result = service.submit_capture(
                user_id="test-user-service",
                content="今天上班很烦，一直被打断",
                input_mode="quick_capture",
                tag_hint="emotion_stress",
            )

            assert result is not None
            assert isinstance(result.acknowledgement, str)
            assert result.acknowledgement.strip() != ""
            assert len(result.recent_signals) >= 1

            capture_count = db.execute(
                select(func.count()).select_from(Capture)
            ).scalar_one()
            raw_memory_count = db.execute(
                select(func.count()).select_from(RawMemory)
            ).scalar_one()

            assert capture_count == 1
            assert raw_memory_count == 1

            saved_capture = db.execute(select(Capture)).scalar_one()
            saved_raw_memory = db.execute(select(RawMemory)).scalar_one()

            assert saved_capture.content == "今天上班很烦，一直被打断"
            assert saved_capture.user_id == "test-user-service"
            assert saved_raw_memory.content == "今天上班很烦，一直被打断"
            assert saved_raw_memory.user_id == "test-user-service"

        finally:
            db.close()
    finally:
        os.environ.pop("DATABASE_URL", None)
        tmpdir.cleanup()


def test_recent_signal_query_reads_back_saved_capture_with_acknowledgement():
    tmpdir, SessionLocal = _prepare_test_db()
    try:
        _patch_demo_user()

        capture_repo_module = import_module("app.repositories.capture_repository")
        classification_module = import_module("app.services.classification_service")
        capture_service_module = import_module("app.services.capture_service")

        reload(capture_repo_module)
        reload(classification_module)
        reload(capture_service_module)

        from app.repositories.capture_repository import CaptureRepository
        from app.services.capture_service import CaptureService
        from app.services.classification_service import ClassificationService

        db = SessionLocal()
        try:
            repository = CaptureRepository(db)
            service = CaptureService(
                repository,
                ClassificationService(),
            )

            result = service.submit_capture(
                user_id="test-user-service",
                content="今天还是很烦",
                input_mode="quick_capture",
                tag_hint="emotion_stress",
            )

            signals = service.list_recent_signals(
                user_id="test-user-service",
                limit=10,
            )

            assert len(signals) >= 1
            assert signals[0].content == "今天还是很烦"
            assert isinstance(signals[0].acknowledgement, str)
            assert signals[0].acknowledgement.strip() != ""
            assert signals[0].acknowledgement == result.acknowledgement

        finally:
            db.close()
    finally:
        os.environ.pop("DATABASE_URL", None)
        tmpdir.cleanup()
