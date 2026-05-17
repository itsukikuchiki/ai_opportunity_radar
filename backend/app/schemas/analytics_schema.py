from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class TrackEventRequest(BaseModel):
    event_name: str = Field(min_length=1, max_length=80)
    properties: dict[str, Any] = Field(default_factory=dict)
    numeric_value: float | None = None
