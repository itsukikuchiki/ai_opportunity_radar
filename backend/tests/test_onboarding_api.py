from sqlalchemy import select


def _headers(user_id: str) -> dict[str, str]:
    return {"X-User-Id": user_id}


def test_complete_onboarding_requires_user_id(client):
    response = client.post(
        "/api/v1/onboarding/complete",
        json={"selected_repeat_area": "work"},
    )

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "MISSING_USER_ID"


def test_complete_onboarding_keeps_profiles_user_scoped(client):
    first = client.post(
        "/api/v1/onboarding/complete",
        headers=_headers("onboarding-user-a"),
        json={
            "selected_repeat_area": "work",
            "selected_ai_help_type": "clarify",
            "selected_output_preference": "brief",
        },
    )
    second = client.post(
        "/api/v1/onboarding/complete",
        headers=_headers("onboarding-user-b"),
        json={
            "selected_repeat_area": "health",
            "selected_ai_help_type": "plan",
            "selected_output_preference": "detailed",
        },
    )

    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text

    from app.core.db import SessionLocal
    from app.models import UserProfile

    with SessionLocal() as db:
        profiles = {
            profile.user_id: profile
            for profile in db.scalars(
                select(UserProfile).where(
                    UserProfile.user_id.in_(
                        ["onboarding-user-a", "onboarding-user-b"]
                    )
                )
            )
        }

    assert set(profiles) == {"onboarding-user-a", "onboarding-user-b"}
    assert profiles["onboarding-user-a"].selected_repeat_area == "work"
    assert profiles["onboarding-user-a"].selected_ai_help_type == "clarify"
    assert profiles["onboarding-user-a"].selected_output_preference == "brief"
    assert profiles["onboarding-user-a"].onboarding_completed is True
    assert profiles["onboarding-user-b"].selected_repeat_area == "health"
    assert profiles["onboarding-user-b"].selected_ai_help_type == "plan"
    assert profiles["onboarding-user-b"].selected_output_preference == "detailed"
    assert profiles["onboarding-user-b"].onboarding_completed is True


def test_legacy_user_scoped_endpoints_require_user_id(client):
    opportunities = client.get("/api/v1/opportunities")
    followup = client.post(
        "/api/v1/followups/missing/submit",
        json={"answer_value": "skip"},
    )

    assert opportunities.status_code == 400
    assert opportunities.json()["detail"]["code"] == "MISSING_USER_ID"
    assert followup.status_code == 400
    assert followup.json()["detail"]["code"] == "MISSING_USER_ID"


def test_followup_answer_cannot_cross_user_boundary(client):
    from datetime import datetime, timedelta, timezone

    from app.core.db import SessionLocal
    from app.models import FollowupAnswer, FollowupQuestion
    from app.repositories.core_repository import ensure_demo_user

    with SessionLocal() as db:
        ensure_demo_user(db, "followup-owner")
        ensure_demo_user(db, "followup-other-user")
        db.add(
            FollowupQuestion(
                id="followup-private",
                user_id="followup-owner",
                raw_memory_id=None,
                question_type="choice",
                question_text="Private question",
                options_json=["yes", "skip"],
                expires_at=datetime.now(timezone.utc) + timedelta(days=1),
            )
        )
        db.commit()

    forbidden = client.post(
        "/api/v1/followups/followup-private/submit",
        headers=_headers("followup-other-user"),
        json={"answer_value": "yes"},
    )
    assert forbidden.status_code == 400

    with SessionLocal() as db:
        question = db.get(FollowupQuestion, "followup-private")
        answers = db.scalars(
            select(FollowupAnswer).where(
                FollowupAnswer.followup_question_id == "followup-private"
            )
        ).all()
        assert question.status == "available"
        assert answers == []

    allowed = client.post(
        "/api/v1/followups/followup-private/submit",
        headers=_headers("followup-owner"),
        json={"answer_value": "yes"},
    )
    assert allowed.status_code == 200, allowed.text

    with SessionLocal() as db:
        question = db.get(FollowupQuestion, "followup-private")
        answer = db.scalars(
            select(FollowupAnswer).where(
                FollowupAnswer.followup_question_id == "followup-private"
            )
        ).one()
        assert question.status == "answered"
        assert answer.user_id == "followup-owner"
