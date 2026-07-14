from pydantic import BaseModel
import os


def normalize_database_url(value: str) -> str:
    """Use the installed psycopg v3 driver for unqualified Postgres URLs."""
    if value.startswith("postgres://"):
        return value.replace("postgres://", "postgresql+psycopg://", 1)
    if value.startswith("postgresql://"):
        return value.replace("postgresql://", "postgresql+psycopg://", 1)
    return value


def database_url_from_environment() -> str:
    value = os.getenv("DATABASE_URL", "").strip()
    railway_environment = os.getenv("RAILWAY_ENVIRONMENT_NAME", "").strip()
    if railway_environment and (not value or value.startswith("sqlite")):
        raise RuntimeError(
            "Railway requires a persistent DATABASE_URL; SQLite fallback is local-only"
        )
    return normalize_database_url(value or "sqlite:///./ai_radar.db")


class Settings(BaseModel):
    app_name: str = "AI Opportunity Radar API"
    api_version: str = "0.7.0"
    database_url: str = database_url_from_environment()
    demo_user_id: str = os.getenv("DEMO_USER_ID", "demo_user")
    app_store_shared_secret: str | None = os.getenv("APP_STORE_SHARED_SECRET")


settings = Settings()
