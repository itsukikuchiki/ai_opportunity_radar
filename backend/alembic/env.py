from logging.config import fileConfig
from pathlib import Path
import sys

from sqlalchemy import engine_from_config, pool
from alembic import context

# 把 backend 根目录加入 sys.path，确保 alembic 能 import app.*
BASE_DIR = Path(__file__).resolve().parent.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from app.core.config import settings
from app.core.db import Base
from app.models import user, capture, raw_memory, pattern, friction, desire, opportunity, followup, weekly_insight, experiment  # noqa

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# 优先使用 settings 里的数据库地址
config.set_main_option("sqlalchemy.url", settings.database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        compare_type=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
