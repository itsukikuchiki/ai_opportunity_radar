from sqlalchemy.orm import Session
from sqlalchemy import select
from app.models import User, UserProfile


def ensure_demo_user(db: Session, user_id: str) -> UserProfile:
    user = db.get(User, user_id)
    if not user:
        db.add(User(id=user_id))
        db.flush()
    profile = db.get(UserProfile, user_id)
    if not profile:
        profile = UserProfile(user_id=user_id, onboarding_completed=False)
        db.add(profile)
        db.flush()
    return profile
