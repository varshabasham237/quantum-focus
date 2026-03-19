"""
Application configuration — loads from environment variables or .env file.
"""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # MongoDB
    MONGODB_URI: str = "mongodb+srv://24241a05gs_db_user:24241a05gs@cluster0.mjtgvtm.mongodb.net/?appName=Cluster0"
    MONGODB_DB_NAME: str = "anti_distraction"

    # JWT
    JWT_SECRET: str = "quantum-focus-secret-key-change-in-production-2026"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # App
    APP_NAME: str = "AntiDistractionSystem"
    DEBUG: bool = True

    class Config:
        env_file = ".env"


settings = Settings()
