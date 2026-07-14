import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.core.config import database_url_from_environment, normalize_database_url


def test_normalizes_railway_postgresql_url_to_psycopg_v3() -> None:
    assert (
        normalize_database_url("postgresql://user:pass@host:5432/db")
        == "postgresql+psycopg://user:pass@host:5432/db"
    )


def test_normalizes_legacy_postgres_url_to_psycopg_v3() -> None:
    assert (
        normalize_database_url("postgres://user:pass@host:5432/db")
        == "postgresql+psycopg://user:pass@host:5432/db"
    )


def test_preserves_explicit_driver_and_sqlite_urls() -> None:
    assert (
        normalize_database_url("postgresql+psycopg://user:pass@host/db")
        == "postgresql+psycopg://user:pass@host/db"
    )
    assert normalize_database_url("sqlite:///./app.db") == "sqlite:///./app.db"


def test_railway_rejects_missing_or_ephemeral_database_url(monkeypatch) -> None:
    monkeypatch.setenv("RAILWAY_ENVIRONMENT_NAME", "production")
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(RuntimeError, match="persistent DATABASE_URL"):
        database_url_from_environment()

    monkeypatch.setenv("DATABASE_URL", "sqlite:///./ai_radar.db")
    with pytest.raises(RuntimeError, match="persistent DATABASE_URL"):
        database_url_from_environment()

    monkeypatch.setenv("DATABASE_URL", "postgresql://user:pass@db/app")
    assert (
        database_url_from_environment()
        == "postgresql+psycopg://user:pass@db/app"
    )


def test_health_reports_database_unavailable_without_exposing_driver_error() -> None:
    # Other integration fixtures intentionally reload app.core.db. Override
    # the dependency object that the currently loaded health route actually
    # captured, rather than a possibly newer function object from core.db.
    from app import main as app_main

    app = app_main.app
    health_database_dependency = app_main.get_db

    class UnavailableDatabase:
        def execute(self, _statement):
            raise OperationalError("SELECT 1", {}, RuntimeError("secret host error"))

    def override_database():
        yield UnavailableDatabase()

    app.dependency_overrides[health_database_dependency] = override_database
    try:
        response = TestClient(app, raise_server_exceptions=False).get("/health")
    finally:
        app.dependency_overrides.pop(health_database_dependency, None)

    assert response.status_code == 503
    assert response.json() == {"detail": "database unavailable"}
    assert "secret host error" not in response.text
