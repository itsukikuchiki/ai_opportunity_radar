from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.core.config import settings
from app.schemas.opportunity_schema import OpportunityFeedbackRequest
from app.services.opportunity_service import OpportunityService

router = APIRouter()


@router.get('')
def list_opportunities(status: str | None = Query(default=None), maturity: str | None = Query(default=None), db: Session = Depends(get_db)) -> dict:
    try:
        items = OpportunityService(db).list_opportunities(settings.demo_user_id, status=status, maturity=maturity)
        return {'success': True, 'data': {'items': items}}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get('/{opportunity_id}')
def get_opportunity_detail(opportunity_id: str, db: Session = Depends(get_db)) -> dict:
    try:
        return {'success': True, 'data': OpportunityService(db).get_opportunity_detail(settings.demo_user_id, opportunity_id)}
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post('/{opportunity_id}/feedback')
def submit_opportunity_feedback(opportunity_id: str, payload: OpportunityFeedbackRequest, db: Session = Depends(get_db)) -> dict:
    try:
        result = OpportunityService(db).submit_feedback(settings.demo_user_id, opportunity_id, payload.feedback_value)
        return {'success': True, 'data': result}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
