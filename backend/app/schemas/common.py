from pydantic import BaseModel
from typing import Any


class ApiError(BaseModel):
    code: str
    message: str


class ApiResponse(BaseModel):
    success: bool = True
    data: Any | None = None
    error: ApiError | None = None
