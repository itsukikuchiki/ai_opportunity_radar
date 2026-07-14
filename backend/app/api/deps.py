from fastapi import Header

from app.api.errors import api_error


def get_user_id(x_user_id: str | None = Header(default=None)) -> str:
    user_id = (x_user_id or "").strip()
    if not user_id:
        raise api_error(
            status_code=400,
            code="MISSING_USER_ID",
            message="Missing X-User-Id",
        )
    return user_id
