from pydantic import BaseModel, Field


class SubmitCaptureRequest(BaseModel):
    content: str = Field(min_length=2, max_length=500)
    input_mode: str
    tag_hint: str | None = None


class SubmitFollowupRequest(BaseModel):
    answer_value: str
