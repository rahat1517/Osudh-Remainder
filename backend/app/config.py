"""অ্যাপের সেটিংস। মান আসে environment variable বা `.env` ফাইল থেকে।"""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

REPO_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Oshudh Reminder API"
    environment: str = "development"
    timezone: str = "Asia/Dhaka"

    # ওষুধের তালিকা (Phase 1)। পরে Supabase database থেকে পড়া হবে।
    drugs_csv_path: Path = REPO_ROOT / "database" / "seed" / "drugs_seed.csv"

    # প্রেসক্রিপশন পাঠক (Phase 2)। key না থাকলে server চালু হবে, কিন্তু /prescriptions/extract 503 দেবে।
    anthropic_api_key: str | None = None
    reader_model: str = "claude-opus-5-5"
    reader_effort: str = "high"

    # পরের phase-এ লাগবে
    supabase_url: str | None = None
    supabase_anon_key: str | None = None
    supabase_service_role_key: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
