from __future__ import annotations

import logging
import re

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.request_observability import (
    REQUEST_ID_HEADER,
    current_request_id,
    install_request_observability,
)


def _test_app() -> FastAPI:
    app = FastAPI()
    install_request_observability(app)

    @app.get("/ok")
    def ok() -> dict[str, str]:
        return {"request_id": current_request_id()}

    @app.get("/fail")
    def fail() -> None:
        raise RuntimeError("private signal text must never reach logs")

    return app


def test_request_id_is_propagated_to_context_and_response() -> None:
    with TestClient(_test_app()) as client:
        response = client.get("/ok", headers={REQUEST_ID_HEADER: "client-request-123"})

    assert response.status_code == 200
    assert response.headers[REQUEST_ID_HEADER] == "client-request-123"
    assert response.json() == {"request_id": "client-request-123"}


def test_invalid_request_id_is_replaced_with_a_safe_generated_value() -> None:
    with TestClient(_test_app()) as client:
        response = client.get(
            "/ok",
            headers={REQUEST_ID_HEADER: "raw diary text / invalid"},
        )

    request_id = response.headers[REQUEST_ID_HEADER]
    assert re.fullmatch(r"[0-9a-f-]{36}", request_id)
    assert response.json() == {"request_id": request_id}


def test_global_exception_response_and_log_exclude_raw_error(
    caplog,
) -> None:
    caplog.set_level(logging.ERROR, logger="signalpath.errors")

    with TestClient(_test_app(), raise_server_exceptions=False) as client:
        response = client.get(
            "/fail",
            headers={REQUEST_ID_HEADER: "request-safe-500"},
        )

    assert response.status_code == 500
    assert response.headers[REQUEST_ID_HEADER] == "request-safe-500"
    assert response.json() == {
        "detail": {
            "code": "internal_error",
            "message": "The service could not complete the request.",
            "request_id": "request-safe-500",
        }
    }
    log_output = caplog.text
    assert "request_id=request-safe-500" in log_output
    assert "error_type=RuntimeError" in log_output
    assert "fingerprint=" in log_output
    assert "private signal text" not in log_output
