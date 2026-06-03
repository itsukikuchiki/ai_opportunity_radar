from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field


class SubmitCaptureRequest(BaseModel):
    content: str
    input_mode: str = "quick_capture"
    tag_hint: Optional[str] = None
    language: str = "en"
    timezone: str = "UTC"


class SubmitFollowupRequest(BaseModel):
    answer_value: str


class ConfirmSignalCardRequest(BaseModel):
    user_confirmation: str
    user_correction_json: dict = Field(default_factory=dict)


class FollowupOptionSchema(BaseModel):
    label: str
    value: str


class FollowupQuestionSchema(BaseModel):
    id: str
    question: str
    options: list[FollowupOptionSchema] = Field(default_factory=list)


class RecentSignalSchema(BaseModel):
    id: Optional[str] = None
    signal_card_id: Optional[str] = None
    content: str
    created_at: Optional[datetime] = None
    local_date: Optional[date] = None
    timezone: Optional[str] = None
    language: Optional[str] = None
    acknowledgement: Optional[str] = None
    emotion: Optional[str] = None
    intensity: Optional[str | int] = None
    scene: Optional[str] = None
    friction: Optional[str] = None
    positive_signal: Optional[str] = None
    energy_load: Optional[str] = None
    user_confirmation: str = "unconfirmed"
    user_correction_json: dict = Field(default_factory=dict)
    included_in_summary: bool = False
    included_in_weekly: bool = False
    included_in_journey: bool = False
    is_legacy: bool = False
    migration_status: str = "native"


class SubmitCaptureResponse(BaseModel):
    acknowledgement: str
    followup: Optional[FollowupQuestionSchema] = None
    recent_signals: list[RecentSignalSchema] = Field(default_factory=list)


# 兼容可能存在的旧命名
class CaptureSubmitResponseSchema(SubmitCaptureResponse):
    pass
