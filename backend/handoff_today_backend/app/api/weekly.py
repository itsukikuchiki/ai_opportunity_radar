from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.core.config import settings
from app.schemas.weekly_schema import WeeklyFeedbackRequest
from app.services.weekly_service import WeeklyService

router = APIRouter()


@router.get('/current')
def get_current_weekly(db: Session = Depends(get_db)) -> dict:
    try:
        return {'success': True, 'data': WeeklyService(db).get_current_weekly(settings.demo_user_id)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get('/{week_start}')
def get_weekly_by_start(week_start: str, db: Session = Depends(get_db)) -> dict:
    try:
        parsed = date.fromisoformat(week_start)
        return {'success': True, 'data': WeeklyService(db).get_weekly_by_start(settings.demo_user_id, parsed)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post('/{week_start}/feedback')
def submit_weekly_feedback(week_start: str, payload: WeeklyFeedbackRequest, db: Session = Depends(get_db)) -> dict:
    try:
        parsed = date.fromisoformat(week_start)
        result = WeeklyService(db).submit_feedback(settings.demo_user_id, parsed, payload.feedback_value)
        return {'success': True, 'data': result}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
