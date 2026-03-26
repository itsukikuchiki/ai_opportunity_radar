from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.core.config import settings
from app.services.memory_service import MemoryService

router = APIRouter()


@router.get('/summary')
def get_memory_summary(db: Session = Depends(get_db)) -> dict:
    try:
        return {'success': True, 'data': MemoryService(db).get_memory_summary(settings.demo_user_id)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
