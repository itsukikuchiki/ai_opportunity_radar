from pydantic import BaseModel


class WeeklyFeedbackRequest(BaseModel):
    feedback_value: str
