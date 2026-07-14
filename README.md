# SignalPath

SignalPath is a local-first reflective app that turns user-confirmed everyday signals into optional MicroActions, LifeExperiments, and evidence-backed Weekly/Journey reflection.

## Canonical Documentation

- [Final app design](docs/active/app_design.md)
- [Canonical data flow](docs/active/data_flow.md)
- [Current documentation index](docs/active/README.md)

Historical PRDs and ReleaseQA files are retained only as delivery/QA evidence. They do not override the final design.

## Repository

- `backend/`: FastAPI, SQLAlchemy, Alembic, AI/eligibility/purchase services.
- `frontend_flutter/`: Flutter application for iOS and supported local targets.
- `docs/active/`: final product/data contracts and current engineering/operations documentation.
- `docs/prd/`: historical Phase and ReleaseQA evidence.

## Local Development

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
flutter run
```

See the active CI, device-build, staging, and rollback documents before preparing a release. A TestFlight build is produced only when explicitly requested.
