from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.core.config import settings
from app.schemas.opportunity_schema import OpportunityFeedbackRequest
from app.services.legacy_telemetry_service import record_legacy_endpoint_call
from app.services.opportunity_service import OpportunityService

router = APIRouter()


@router.get('')
def list_opportunities(
    request: Request,
    status: str | None = Query(default=None),
    maturity: str | None = Query(default=None),
    x_user_id: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> dict:
    try:
        record_legacy_endpoint_call(
            db=db,
            counter_name="legacy_opportunities_endpoint_call_count",
            endpoint="/api/v1/opportunities",
            request=request,
            user_id=x_user_id,
        )
        items = OpportunityService(db).list_opportunities(settings.demo_user_id, status=status, maturity=maturity)
        return {'success': True, 'data': {'items': items}}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get('/{opportunity_id}')
def get_opportunity_detail(
    opportunity_id: str,
    request: Request,
    x_user_id: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> dict:
    try:
        record_legacy_endpoint_call(
            db=db,
            counter_name="legacy_opportunities_endpoint_call_count",
            endpoint="/api/v1/opportunities/{opportunity_id}",
            request=request,
            user_id=x_user_id,
        )
        return {'success': True, 'data': OpportunityService(db).get_opportunity_detail(settings.demo_user_id, opportunity_id)}
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post('/{opportunity_id}/feedback')
def submit_opportunity_feedback(
    opportunity_id: str,
    payload: OpportunityFeedbackRequest,
    request: Request,
    x_user_id: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> dict:
    try:
        record_legacy_endpoint_call(
            db=db,
            counter_name="legacy_opportunities_endpoint_call_count",
            endpoint="/api/v1/opportunities/{opportunity_id}/feedback",
            request=request,
            user_id=x_user_id,
        )
        result = OpportunityService(db).submit_feedback(settings.demo_user_id, opportunity_id, payload.feedback_value)
        return {'success': True, 'data': result}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
