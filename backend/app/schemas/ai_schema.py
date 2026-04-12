from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.schemas.capture_schema import FollowupQuestionSchema


class EntryInputSchema(BaseModel):
    id: str | None = None
    content: str
    created_at: datetime | None = None
    acknowledgement: str | None = None


class CaptureReplyRequest(BaseModel):
    content: str
    recent_assistant_texts: list[str] = Field(default_factory=list)
    focus_area: str | None = None


class CaptureReplyResponse(BaseModel):
    acknowledgement: str
    followup: FollowupQuestionSchema | None = None


class TodaySummaryRequest(BaseModel):
    date: str
    entry_count: int = 0
    entries: list[EntryInputSchema] = Field(default_factory=list)
    focus_area: str | None = None


class TodaySummaryResponse(BaseModel):
    observation: str
    suggestion: str


class WeeklyGenerateRequest(BaseModel):
    week_start: str
    week_end: str
    entry_count: int = 0
    entries: list[dict[str, Any]] = Field(default_factory=list)
    day_counts: dict[str, int] = Field(default_factory=dict)
    top_tokens: list[str] = Field(default_factory=list)
    focus_area: str | None = None


class WeeklyGenerateResponse(BaseModel):
    week_start: str
    week_end: str
    status: str
    key_insight: str | None = None
    patterns: list[dict[str, Any]] = Field(default_factory=list)
    frictions: list[dict[str, Any]] = Field(default_factory=list)
    best_action: str | None = None
    opportunity_snapshot: dict[str, Any] | None = None
    feedback_submitted: bool = False


class JourneyGenerateRequest(BaseModel):
    snapshot_date: str
    entry_count: int = 0
    entries: list[dict[str, Any]] = Field(default_factory=list)
    top_tokens: list[str] = Field(default_factory=list)
    total_days: int = 0
    focus_area: str | None = None


class JourneyGenerateResponse(BaseModel):
    patterns: list[dict[str, Any]] = Field(default_factory=list)
    frictions: list[dict[str, Any]] = Field(default_factory=list)
    desires: list[dict[str, Any]] = Field(default_factory=list)
    experiments: list[dict[str, Any]] = Field(default_factory=list)
