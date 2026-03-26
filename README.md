# AI Opportunity Radar

MVP scaffold and runnable starter for a life-observation AI that captures signals, builds memory, generates weekly insight, and identifies AI opportunities.

## Structure

- `backend/` FastAPI + SQLAlchemy + Alembic
- `frontend_flutter/` Flutter Web/App scaffold with Provider + go_router
- `docs/prd/` PRD v0.1 - v0.7

## Quick start

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

### Flutter

```bash
cd frontend_flutter
flutter pub get
flutter run -d chrome
```

## Current scope

This repository now includes:

- capture submit
- follow-up submit
- weekly fetch + weekly feedback
- opportunity list/detail/feedback
- memory summary
- SQLite-friendly SQLAlchemy models
- Alembic bootstrap
- Provider-based Flutter state wiring

## Notes

- The backend and Flutter skeleton are designed for a local demo first.
- The current LLM generation layer is stubbed with deterministic text so you can wire the full flow before swapping to a real model.
- The container used to generate this package did not have `sqlalchemy` available at runtime, so end-to-end execution was not verified here. The files are prepared for local setup using `requirements.txt`.
