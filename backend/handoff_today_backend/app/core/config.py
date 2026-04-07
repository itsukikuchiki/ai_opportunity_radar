from pydantic import BaseModel
import os


class Settings(BaseModel):
    app_name: str = "AI Opportunity Radar API"
    api_version: str = "0.7.0"
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./ai_radar.db")
    demo_user_id: str = os.getenv("DEMO_USER_ID", "demo_user")


settings = Settings()
