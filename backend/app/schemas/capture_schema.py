from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class SubmitCaptureRequest(BaseModel):
    content: str
    input_mode: str = "quick_capture"
    tag_hint: Optional[str] = None


class SubmitFollowupRequest(BaseModel):
    answer_value: str


class FollowupOptionSchema(BaseModel):
    label: str
    value: str


class FollowupQuestionSchema(BaseModel):
    id: str
    question: str
    options: list[FollowupOptionSchema] = Field(default_factory=list)


class RecentSignalSchema(BaseModel):
    id: Optional[str] = None
    content: str
    created_at: Optional[datetime] = None
    acknowledgement: Optional[str] = None


class SubmitCaptureResponse(BaseModel):
    acknowledgement: str
    followup: Optional[FollowupQuestionSchema] = None
    recent_signals: list[RecentSignalSchema] = Field(default_factory=list)


# 兼容可能存在的旧命名
class CaptureSubmitResponseSchema(SubmitCaptureResponse):
    pass
