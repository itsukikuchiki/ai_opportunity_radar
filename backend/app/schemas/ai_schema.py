
from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


EmotionLiteral = Literal["positive", "negative", "mixed", "neutral"]
IntensityLiteral = Literal["low", "medium", "high"]


class FollowupOptionSchema(BaseModel):
    label: str
    value: str


class FollowupQuestionSchema(BaseModel):
    id: str
    question: str
    options: list[FollowupOptionSchema] = Field(default_factory=list)


class CaptureReplyRequest(BaseModel):
    content: str
    recent_assistant_texts: list[str] = Field(default_factory=list)
    focus_area: Optional[str] = None


class CaptureReplyResponse(BaseModel):
    acknowledgement: str
    observation: str
    try_next: str
    emotion: EmotionLiteral
    intensity: IntensityLiteral
    scene_tags: list[str] = Field(default_factory=list)
    intent_tags: list[str] = Field(default_factory=list)
    followup: Optional[FollowupQuestionSchema] = None


class AiTimelineEntry(BaseModel):
    id: Optional[str] = None
    content: str
    created_at: Optional[datetime] = None
    acknowledgement: Optional[str] = None
    observation: Optional[str] = None
    try_next: Optional[str] = None
    emotion: Optional[EmotionLiteral] = None
    intensity: Optional[IntensityLiteral] = None
    scene_tags: list[str] = Field(default_factory=list)
    intent_tags: list[str] = Field(default_factory=list)


class TodaySummaryRequest(BaseModel):
    date: date | str
    entry_count: int = 0
    entries: list[AiTimelineEntry] = Field(default_factory=list)
    focus_area: Optional[str] = None


class TodaySummaryResponse(BaseModel):
    observation: str
    suggestion: str


class WeeklyInsightItem(BaseModel):
    name: str
    summary: str


class OpportunitySnapshotSchema(BaseModel):
    name: str
    summary: str


class WeeklyGenerateRequest(BaseModel):
    week_start: str
    week_end: str
    entry_count: int = 0
    entries: list[AiTimelineEntry] = Field(default_factory=list)
    day_counts: dict[str, int] = Field(default_factory=dict)
    top_tokens: list[str] = Field(default_factory=list)
    focus_area: Optional[str] = None


class WeeklyGenerateResponse(BaseModel):
    week_start: str
    week_end: str
    status: str
    key_insight: Optional[str] = None
    patterns: list[WeeklyInsightItem] = Field(default_factory=list)
    frictions: list[WeeklyInsightItem] = Field(default_factory=list)
    best_action: Optional[str] = None
    opportunity_snapshot: Optional[OpportunitySnapshotSchema] = None
    feedback_submitted: bool = False


class JourneyGenerateRequest(BaseModel):
    snapshot_date: str
    entry_count: int = 0
    entries: list[AiTimelineEntry] = Field(default_factory=list)
    top_tokens: list[str] = Field(default_factory=list)
    total_days: int = 0
    focus_area: Optional[str] = None


class JourneyGenerateResponse(BaseModel):
    patterns: list[WeeklyInsightItem] = Field(default_factory=list)
    frictions: list[WeeklyInsightItem] = Field(default_factory=list)
    desires: list[WeeklyInsightItem] = Field(default_factory=list)
    experiments: list[WeeklyInsightItem] = Field(default_factory=list)


class OpportunityExplanationRequest(BaseModel):
    patterns: list[dict[str, Any]] = Field(default_factory=list)
    frictions: list[dict[str, Any]] = Field(default_factory=list)
    opportunities: list[dict[str, Any]] = Field(default_factory=list)


class OpportunityExplanationResponse(BaseModel):
    why_this_opportunity: str
    evidence_summary: list[str] = Field(default_factory=list)
    solution_fit_explanation: str
    next_step: str
    user_facing_summary: str


class FollowupGenerateRequest(BaseModel):
    patterns: list[dict[str, Any]] = Field(default_factory=list)
    frictions: list[dict[str, Any]] = Field(default_factory=list)
    opportunities: list[dict[str, Any]] = Field(default_factory=list)


class FollowupGenerateResponse(BaseModel):
    question_type: str
    question_text: str
    options: list[FollowupOptionSchema] = Field(default_factory=list)


class LightDialogTurnSchema(BaseModel):
    role: Literal["user", "assistant"]
    text: str


class LightDialogRequest(BaseModel):
    capture_content: str
    capture_acknowledgement: Optional[str] = None
    capture_observation: Optional[str] = None
    capture_try_next: Optional[str] = None
    history: list[LightDialogTurnSchema] = Field(default_factory=list)
    user_message: str
    focus_area: Optional[str] = None


class LightDialogResponse(BaseModel):
    reply: str
    suggested_prompts: list[str] = Field(default_factory=list)


class DeepWeeklyRequest(BaseModel):
    week_start: str
    week_end: str
    key_insight: Optional[str] = None
    patterns: list[dict[str, Any]] = Field(default_factory=list)
    frictions: list[dict[str, Any]] = Field(default_factory=list)
    best_action: Optional[str] = None
    chart_data: list[dict[str, Any]] = Field(default_factory=list)
    focus_area: Optional[str] = None


class DeepWeeklyResponse(BaseModel):
    summary: str
    root_tension: str
    hidden_pattern: str
    next_focus: str
    risk_note: str
    key_nodes: list[str] = Field(default_factory=list)
