from fastapi import Header, HTTPException


def get_user_id(x_user_id: str | None = Header(default=None)) -> str:
    user_id = (x_user_id or "").strip()
    if not user_id:
        raise HTTPException(status_code=400, detail="Missing X-User-Id")
    return user_id
