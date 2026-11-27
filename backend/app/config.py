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
    # Google Gemini (free key from aistudio.google.com): the second reader when there is no
    # ANTHROPIC_API_KEY. Used only for users who agreed, as Google may use free-tier inputs.
    gemini_api_key: str | None = None
    # One name, or several separated by commas, tried in order when one is overloaded or retired
    gemini_model: str = "gemini-3.8-flash"
    # Longest wait for Gemini; then the own model's reading is shown instead
    gemini_deadline_seconds: float = 8

    # Direct PostgreSQL connection for server jobs (Phase 6), e.g. the Supabase pooler URL.
    # Uses a privileged role: never expose it to clients.
    database_url: str | None = None
    # Firebase Cloud Messaging: path to a service-account JSON file
    fcm_service_account_file: Path | None = None

    # Authentication (Phase 7). Tokens are verified with the project's signing keys
    # (<supabase_url>/auth/v1/.well-known/jwks.json) and/or the legacy HS256 secret.
    supabase_url: str | None = None
    supabase_jwt_secret: str | None = None
    # None = required in production, optional elsewhere. Production refuses to start without it.
    require_auth: bool | None = None

    # Prescription reads per user: (max, window seconds) pairs
    ai_rate_limits: list[tuple[int, float]] = [(5, 60), (30, 3600), (100, 86400)]

    # Assistant (Phase 8): chat works best at low effort
    assistant_model: str = "claude-opus-5-5"
    assistant_effort: str = "low"
    assistant_rate_limits: list[tuple[int, float]] = [(10, 60), (100, 86400)]

    # SMS and voice-call reminders (Phase 10). Without a gateway, the job only logs messages.
    sms_gateway_url: str | None = None
    sms_api_key: str | None = None
    sms_sender_id: str | None = None
    voice_gateway_url: str | None = None
    voice_api_key: str | None = None
    sms_segment_bdt: float = 0.35
    call_bdt: float = 1.0
    max_sms_per_patient_day: int = 6
    max_calls_per_patient_day: int = 3
    escalation_monthly_budget_bdt: float = 5000.0

    # Prescription reader:
    #   auto   Claude if ANTHROPIC_API_KEY is set, otherwise the free PaddleOCR reader
    #   cloud  Claude only
    #   ocr    PaddleOCR + rules only (free, on this server)
    #   local  self-hosted vision-language model (LOCAL_READER_URL) only
    #   hybrid self-hosted first (the model at LOCAL_READER_URL, else PaddleOCR); Claude when unsure
    reader_mode: str = "auto"
    local_reader_url: str | None = None
    local_reader_model: str = "oshudh-reader"
    # Fine-tuned PaddleOCR recognition model (ONNX) and its character list; pretrained if unset
    ocr_rec_model_path: str | None = None
    ocr_rec_keys_path: str | None = None

    # Training-data collection (Phase 11). Needs DATABASE_URL, the service-role key for the private
    # storage bucket, and a secret pepper for grouping keys.
    supabase_service_role_key: str | None = None
    training_pepper: str | None = None

    # Optional error monitoring. Personal data is scrubbed before sending.
    sentry_dsn: str | None = None

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def auth_required(self) -> bool:
        return self.require_auth if self.require_auth is not None else self.is_production


@lru_cache
def get_settings() -> Settings:
    return Settings()
