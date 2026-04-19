from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class WeeklyFeedbackRequest(BaseModel):
    feedback_value: str


class WeeklyChartPointSchema(BaseModel):
    date: str
    signal_count: int = 0
    mood_score: float = 0.0
    friction_score: float = 0.0
    has_positive_signal: bool = False


class WeeklyInsightResponse(BaseModel):
    week_start: str
    week_end: str
    status: Literal["not_started", "insufficient_data", "light_ready", "ready", "available"]
    key_insight: str | None = None
    patterns: list[dict] = Field(default_factory=list)
    frictions: list[dict] = Field(default_factory=list)
    best_action: str | None = None
    opportunity_snapshot: dict | None = None
    feedback_submitted: bool = False
    chart_data: list[WeeklyChartPointSchema] = Field(default_factory=list)
