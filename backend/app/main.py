import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import anthropic
from fastapi import FastAPI

from app import __version__
from app.api import assistant, drugs, health, legal, prescriptions, schedules, training
from app.assistant.service import AssistantService
from app.config import Settings, get_settings
from app.drugs.catalog import load_csv
from app.drugs.matcher import DrugMatcher
from app.observability import RequestIdMiddleware, init_sentry
from app.prescriptions.local_reader import HybridReader, LocalModelReader
from app.prescriptions.ocr_reader import OcrPrescriptionReader, RapidOcrEngine
from app.prescriptions.reader import ClaudePrescriptionReader
from app.prescriptions.service import PrescriptionService
from app.prescriptions.verifier import PrescriptionVerifier
from app.security.auth import TokenVerifier
from app.security.rate_limit import SlidingWindowLimiter

logger = logging.getLogger(__name__)


def build_token_verifier(settings: Settings) -> TokenVerifier | None:
    if not (settings.supabase_url or settings.supabase_jwt_secret):
        if settings.auth_required:
            raise RuntimeError(
                "Authentication is required but neither SUPABASE_URL nor SUPABASE_JWT_SECRET is set"
            )
        logger.warning("Authentication is DISABLED (development only)")
        return None
    base = settings.supabase_url.rstrip("/") if settings.supabase_url else None
    return TokenVerifier(
        jwks_url=f"{base}/auth/v1/.well-known/jwks.json" if base else None,
        jwt_secret=settings.supabase_jwt_secret,
        issuer=f"{base}/auth/v1" if base else None,
    )


READER_MODES = {"auto", "cloud", "ocr", "local", "hybrid"}


def build_ocr_reader(settings: Settings):
    return OcrPrescriptionReader(
        RapidOcrEngine(settings.ocr_rec_model_path, settings.ocr_rec_keys_path)
    )


def build_reader(settings: Settings, cloud):
    """The prescription reader for `settings.reader_mode`; None if reading is unavailable.

    `cloud` is the Claude reader, or None without an API key.
    """
    mode = settings.reader_mode
    if mode not in READER_MODES:
        raise RuntimeError(f"READER_MODE must be one of {sorted(READER_MODES)}, not {mode!r}")
    if mode == "auto":
        return cloud or build_ocr_reader(settings)
    if mode == "cloud":
        return cloud
    if mode == "ocr":
        return build_ocr_reader(settings)
    if mode == "local":
        if not settings.local_reader_url:
            raise RuntimeError("READER_MODE=local needs LOCAL_READER_URL")
        return LocalModelReader(settings.local_reader_url, settings.local_reader_model)
    # hybrid
    local = (
        LocalModelReader(settings.local_reader_url, settings.local_reader_model)
        if settings.local_reader_url
        else build_ocr_reader(settings)
    )
    return HybridReader(local, cloud) if cloud else local


def build_training_service(settings: Settings):
    from app.training.deid import NoLineDetector
    from app.training.repository import PostgresTrainingRepository
    from app.training.service import TrainingService
    from app.training.storage import SupabaseStorageStore

    needed = (
        settings.database_url,
        settings.supabase_url,
        settings.supabase_service_role_key,
        settings.training_pepper,
    )
    if not all(needed):
        return None
    return TrainingService(
        PostgresTrainingRepository(settings.database_url),
        SupabaseStorageStore(settings.supabase_url, settings.supabase_service_role_key),
        NoLineDetector(),  # replace with TesseractLineDetector where OCR is installed
        settings.training_pepper,
    )


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    app.state.token_verifier = build_token_verifier(settings)
    app.state.ai_rate_limiter = SlidingWindowLimiter(settings.ai_rate_limits)
    app.state.assistant_rate_limiter = SlidingWindowLimiter(settings.assistant_rate_limits)
    catalog, report = load_csv(settings.drugs_csv_path)
    for err in report.errors:
        logger.warning("Drug catalogue error: %s", err)
    matcher = DrugMatcher(catalog)
    app.state.drug_matcher = matcher
    logger.info("Loaded %d drugs", len(catalog))

    app.state.prescription_service = None
    app.state.assistant_service = None
    app.state.training_service = build_training_service(settings)
    cloud = None
    if settings.anthropic_api_key:
        client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        cloud = ClaudePrescriptionReader(client, settings.reader_model, settings.reader_effort)
        app.state.assistant_service = AssistantService(
            client, matcher, settings.assistant_model, settings.assistant_effort
        )
    else:
        logger.warning("ANTHROPIC_API_KEY is not set: the assistant is disabled")
    reader = build_reader(settings, cloud)
    if reader is None:
        logger.warning("No prescription reader for READER_MODE=%s", settings.reader_mode)
    else:
        logger.info("Prescription reader: %s", type(reader).__name__)
        for r in (reader, getattr(reader, "_local", None)):
            if isinstance(r, OcrPrescriptionReader):
                r.warm_up_in_background()
        app.state.prescription_service = PrescriptionService(reader, PrescriptionVerifier(matcher))
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    if settings.sentry_dsn:
        init_sentry(settings.sentry_dsn, settings.environment, __version__)
    app = FastAPI(title=settings.app_name, version=__version__, lifespan=lifespan)
    app.add_middleware(RequestIdMiddleware)
    app.include_router(health.router)
    app.include_router(legal.router)
    app.include_router(drugs.router)
    app.include_router(prescriptions.router)
    app.include_router(schedules.router)
    app.include_router(assistant.router)
    app.include_router(training.router)
    return app


app = create_app()
