from pydantic import BaseModel


class OpportunityFeedbackRequest(BaseModel):
    feedback_value: str
