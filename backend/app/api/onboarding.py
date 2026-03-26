from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.core.db import get_db
from app.core.config import settings
from app.models import UserProfile
from app.repositories.core_repository import ensure_demo_user

router = APIRouter()

class OnboardingCompleteRequest(BaseModel):
    selected_repeat_area: str | None = None
    selected_ai_help_type: str | None = None
    selected_output_preference: str | None = None


@router.post('/complete')
def complete_onboarding(payload: OnboardingCompleteRequest, db: Session = Depends(get_db)) -> dict:
    try:
        ensure_demo_user(db, settings.demo_user_id)
        profile = db.get(UserProfile, settings.demo_user_id)
        profile.selected_repeat_area = payload.selected_repeat_area
        profile.selected_ai_help_type = payload.selected_ai_help_type
        profile.selected_output_preference = payload.selected_output_preference
        profile.onboarding_completed = True
        db.commit()
        return {'success': True, 'data': {'message': 'onboarding completed'}}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
