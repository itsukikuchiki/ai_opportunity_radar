from __future__ import annotations

import contextvars
import hashlib
import logging
import re
import traceback
import uuid
from collections.abc import Callable

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response

REQUEST_ID_HEADER = "X-Request-Id"
_SAFE_REQUEST_ID = re.compile(r"^[A-Za-z0-9._:-]{1,96}$")
_request_id: contextvars.ContextVar[str] = contextvars.ContextVar(
    "signalpath_request_id",
    default="unavailable",
)
_logger = logging.getLogger("signalpath.errors")


def current_request_id() -> str:
    return _request_id.get()


def install_request_observability(app: FastAPI) -> None:
    @app.middleware("http")
    async def request_observability(
        request: Request,
        call_next: Callable,
    ) -> Response:
        request_id = _normalized_request_id(request.headers.get(REQUEST_ID_HEADER))
        token = _request_id.set(request_id)
        try:
            try:
                response = await call_next(request)
            except Exception as exc:  # noqa: BLE001 - global safety boundary
                _log_privacy_safe_exception(exc, request_id)
                response = JSONResponse(
                    status_code=500,
                    content={
                        "detail": {
                            "code": "internal_error",
                            "message": "The service could not complete the request.",
                            "request_id": request_id,
                        }
                    },
                )
            response.headers[REQUEST_ID_HEADER] = request_id
            return response
        finally:
            _request_id.reset(token)


def _normalized_request_id(candidate: str | None) -> str:
    if candidate and _SAFE_REQUEST_ID.fullmatch(candidate):
        return candidate
    return str(uuid.uuid4())


def _log_privacy_safe_exception(exc: Exception, request_id: str) -> None:
    _logger.error(
        "unhandled_exception request_id=%s error_type=%s fingerprint=%s",
        request_id,
        type(exc).__name__,
        _exception_fingerprint(exc),
    )


def _exception_fingerprint(exc: Exception) -> str:
    frames = traceback.extract_tb(exc.__traceback__)
    if frames:
        frame = frames[-1]
        source = f"{type(exc).__name__}|{frame.name}|{frame.lineno}"
    else:
        source = type(exc).__name__
    return hashlib.sha256(source.encode("utf-8")).hexdigest()[:12]
