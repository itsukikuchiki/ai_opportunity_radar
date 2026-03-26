from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.captures import router as captures_router
from app.api.followups import router as followups_router
from app.api.weekly import router as weekly_router
from app.api.opportunities import router as opportunities_router
from app.api.memory import router as memory_router
from app.api.onboarding import router as onboarding_router
from app.core.db import Base, engine
import app.models  # noqa: F401

app = FastAPI(
    title="AI Opportunity Radar API",
    version="0.8.1",
)


@app.on_event("startup")
def on_startup() -> None:
    Base.metadata.create_all(bind=engine)


# v0.8.1:
# Flutter web dev server often uses random localhost ports,
# so exact allow_origins is not enough.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(onboarding_router, prefix="/api/v1/onboarding", tags=["onboarding"])
app.include_router(captures_router, prefix="/api/v1/captures", tags=["captures"])
app.include_router(followups_router, prefix="/api/v1/followups", tags=["followups"])
app.include_router(weekly_router, prefix="/api/v1/weekly", tags=["weekly"])
app.include_router(opportunities_router, prefix="/api/v1/opportunities", tags=["opportunities"])
app.include_router(memory_router, prefix="/api/v1/memory", tags=["memory"])


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "version": "0.8.1"}
