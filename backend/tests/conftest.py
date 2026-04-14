import os
import sys
import tempfile
from collections.abc import Generator
from importlib import import_module, reload

import pytest
from fastapi.testclient import TestClient


@pytest.fixture()
def client() -> Generator[TestClient, None, None]:
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_ai_radar.db")
        os.environ["DATABASE_URL"] = f"sqlite:///{db_path}"

        # 1) 先重载 config / db，让新的 DATABASE_URL 生效
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
        from app.core.db import Base, engine
        Base.metadata.create_all(bind=engine)

        # 5) 关键：所有引用了 get_db 的 API 模块都要 reload
        api_captures = import_module("app.api.captures")
        api_followups = import_module("app.api.followups")
        api_weekly = import_module("app.api.weekly")
        api_opportunities = import_module("app.api.opportunities")
        api_memory = import_module("app.api.memory")
        api_onboarding = import_module("app.api.onboarding")
        api_ai = import_module("app.api.ai")

        reload(api_captures)
        reload(api_followups)
        reload(api_weekly)
        reload(api_opportunities)
        reload(api_memory)
        reload(api_onboarding)
        reload(api_ai)

        # 6) 最后再 reload app.main，让 app 重新 include 这些新的 router
        app_main = import_module("app.main")
        reload(app_main)

        from app.main import app

        with TestClient(app) as test_client:
            yield test_client

        os.environ.pop("DATABASE_URL", None)
