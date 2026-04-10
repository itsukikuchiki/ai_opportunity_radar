from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.services.memory_service import MemoryService
from app.api.deps import get_user_id

router = APIRouter()


@router.get('/summary')
def get_memory_summary(
    user_id: str = Depends(get_user_id),
    db: Session = Depends(get_db),
) -> dict:
    try:
        return {'success': True, 'data': MemoryService(db).get_memory_summary(user_id)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
