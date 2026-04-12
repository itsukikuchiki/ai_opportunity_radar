from sqlalchemy import select

from app.core.db import SessionLocal
from app.models import User
from app.repositories.capture_repository import CaptureRepository


def main() -> None:
    db = SessionLocal()
    try:
        user_ids = list(db.scalars(select(User.id)))
        total_created = 0

        for user_id in user_ids:
            repo = CaptureRepository(db)
            created = repo.backfill_missing_raw_memories(
                user_id=user_id,
                commit=True,
            )
            total_created += created
            print(f"[backfill] user={user_id} created_raw_memories={created}")

        print(f"[backfill] done total_created={total_created}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
