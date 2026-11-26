"""Application settings, read from environment variables or a `.env` file."""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

REPO_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Oshudh Reminder API"
    environment: str = "development"
    timezone: str = "Asia/Dhaka"

    # Drug catalogue (Phase 1). Will be read from the Supabase database later.
    drugs_csv_path: Path = REPO_ROOT / "database" / "seed" / "drugs_seed.csv"

    # Prescription reader (Phase 2). Without a key the server still starts, but
    # /prescriptions/extract returns 503 ai_not_configured.
    anthropic_api_key: str | None = None
    reader_model: str = "claude-opus-5-5"
    reader_effort: str = "high"

    # Direct PostgreSQL connection for server jobs (Phase 6), e.g. the Supabase pooler URL.
    # Uses a privileged role: never expose it to clients.
    database_url: str | None = None
    # Firebase Cloud Messaging: path to a service-account JSON file
    fcm_service_account_file: Path | None = None

    # Needed in later phases
    supabase_url: str | None = None
    supabase_anon_key: str | None = None
    supabase_service_role_key: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
