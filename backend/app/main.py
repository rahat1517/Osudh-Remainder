import logging
import threading
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import anthropic
from fastapi import FastAPI

from app import __version__
from app.api import (
    assistant,
    download,
    drugs,
    health,
    legal,
    prescriptions,
    schedules,
    training,
)
from app.assistant.service import AssistantService
from app.config import Settings, get_settings
from app.drugs.catalog import load_csv
from app.drugs.matcher import DrugMatcher
from app.observability import RequestIdMiddleware, init_sentry
from app.prescriptions.gemini_reader import GeminiPrescriptionReader
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


def _redactor(ocr_reader: OcrPrescriptionReader):
    """Blacks out personal lines (name, phone, age, address) using the OCR engine's lines."""
    from app.training.deid import OcrLineDetector, redact

    detector = OcrLineDetector(ocr_reader._engine)
    return lambda image: redact(image, detector.detect(image))[0]


def build_reader(settings: Settings, cloud, *, cloud_needs_consent: bool = False):
    """The prescription reader for `settings.reader_mode`; None if reading is unavailable.

    `cloud` is the cloud reader (Claude, or Gemini), or None without an API key.
    `cloud_needs_consent`: it may keep what it is sent (Gemini's free tier), so it is used only as
    a second reader, for users who agreed, on a redacted photo.
    """
    mode = settings.reader_mode
    if mode not in READER_MODES:
        raise RuntimeError(f"READER_MODE must be one of {sorted(READER_MODES)}, not {mode!r}")
    if mode == "auto":
        if cloud and not cloud_needs_consent:
            return cloud
        mode = "hybrid"  # own model first; the consent-only cloud reader when it is unsure
    if mode == "cloud":
        if cloud_needs_consent:
            raise RuntimeError("READER_MODE=cloud needs a cloud reader that does not need consent")
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
    if not cloud:
        return local
    redact = _redactor(local) if isinstance(local, OcrPrescriptionReader) else None
    if cloud_needs_consent and redact is None:
        # Never send an unredacted photo to a service that may keep it
        redact = _redactor(build_ocr_reader(settings))
    return HybridReader(local, cloud, needs_consent=cloud_needs_consent, redact=redact)


def build_training_service(settings: Settings, ocr_engine=None):
    """None unless DATABASE_URL, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and TRAINING_PEPPER are set.

    `ocr_engine` (the prescription reader's, to share its memory) finds the lines to redact.
    """
    from app.training.deid import OcrLineDetector
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
        OcrLineDetector(
            ocr_engine or RapidOcrEngine(settings.ocr_rec_model_path, settings.ocr_rec_keys_path)
        ),
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
    warming: list = []
    cloud = None
    if settings.anthropic_api_key:
        client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        cloud = ClaudePrescriptionReader(client, settings.reader_model, settings.reader_effort)
        app.state.assistant_service = AssistantService(
            client, matcher, settings.assistant_model, settings.assistant_effort
        )
    else:
        logger.warning("ANTHROPIC_API_KEY is not set: the assistant is disabled")
    cloud_needs_consent = False
    if cloud is None and settings.gemini_api_key:
        cloud = GeminiPrescriptionReader(settings.gemini_api_key, settings.gemini_model)
        cloud_needs_consent = True
        logger.warning("Second reader: Gemini %s, for users who agreed", cloud.models)
        # Which models this key may use: names change as Google retires models (see GEMINI_MODEL)
        threading.Thread(
            target=lambda r=cloud: logger.warning(
                "Gemini models for this key: %s", ", ".join(r.available_models()) or "unknown"
            ),
            daemon=True,
        ).start()
    reader = build_reader(settings, cloud, cloud_needs_consent=cloud_needs_consent)
    ocr_engine = None
    if reader is None:
        logger.warning("No prescription reader for READER_MODE=%s", settings.reader_mode)
    else:
        logger.info("Prescription reader: %s", type(reader).__name__)
        for r in (reader, getattr(reader, "_local", None)):
            # (the hybrid's own OCR reader; a redactor's engine is shared with it)
            if isinstance(r, OcrPrescriptionReader):
                warming.append(r.warm_up_in_background())
                ocr_engine = r._engine
        app.state.prescription_service = PrescriptionService(reader, PrescriptionVerifier(matcher))
    app.state.training_service = build_training_service(settings, ocr_engine)
    logger.info("Training-example collection: %s", "on" if app.state.training_service else "off")
    yield
    # Let a model load that is still running finish, so shutdown never aborts mid-load
    for thread in warming:
        if thread is not None:
            thread.join(timeout=60)


def create_app() -> FastAPI:
    settings = get_settings()
    if settings.sentry_dsn:
        init_sentry(settings.sentry_dsn, settings.environment, __version__)
    app = FastAPI(title=settings.app_name, version=__version__, lifespan=lifespan)
    app.add_middleware(RequestIdMiddleware)
    app.include_router(health.router)
    app.include_router(legal.router)
    app.include_router(download.router)
    app.include_router(drugs.router)
    app.include_router(prescriptions.router)
    app.include_router(schedules.router)
    app.include_router(assistant.router)
    app.include_router(training.router)
    return app


app = create_app()
