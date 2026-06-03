from __future__ import annotations

from app.core.db import SessionLocal
from app.models import User
from app.repositories.capture_repository import CaptureRepository


def migrate_all_users() -> dict[str, dict[str, int]]:
    db = SessionLocal()
    try:
        repository = CaptureRepository(db)
        users = db.query(User).all()
        results: dict[str, dict[str, int]] = {}
        for user in users:
            results[user.id] = repository.migrate_legacy_signal_cards(
                user_id=user.id,
                commit=True,
            )
        return results
    finally:
        db.close()


if __name__ == "__main__":
    for user_id, result in migrate_all_users().items():
        print(user_id, result)
