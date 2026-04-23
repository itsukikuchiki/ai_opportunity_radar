from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field

EmotionLiteral = Literal["positive", "negative", "mixed", "neutral"]
IntensityLiteral = Literal["low", "medium", "high"]


class SelfReviewEntrySchema(BaseModel):
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


class SelfReviewRequest(BaseModel):
    entry_count: int = 0
    entries: list[SelfReviewEntrySchema] = Field(default_factory=list)
    top_tokens: list[str] = Field(default_factory=list)
    total_days: int = 0
    focus_area: Optional[str] = None


class SelfReviewResponse(BaseModel):
    status: str
    reviewed_days: int = 0
    repeated_blockers: list[str] = Field(default_factory=list)
    main_drains: list[str] = Field(default_factory=list)
    helping_patterns: list[str] = Field(default_factory=list)
    closing_note: str = ""
