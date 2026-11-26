import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import anthropic
from fastapi import FastAPI

from app import __version__
from app.api import drugs, health, prescriptions, schedules
from app.config import Settings, get_settings
from app.drugs.catalog import load_csv
from app.drugs.matcher import DrugMatcher
from app.observability import RequestIdMiddleware, init_sentry
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


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    app.state.token_verifier = build_token_verifier(settings)
    app.state.ai_rate_limiter = SlidingWindowLimiter(settings.ai_rate_limits)
    catalog, report = load_csv(settings.drugs_csv_path)
    for err in report.errors:
        logger.warning("Drug catalogue error: %s", err)
    matcher = DrugMatcher(catalog)
    app.state.drug_matcher = matcher
    logger.info("Loaded %d drugs", len(catalog))

    app.state.prescription_service = None
    if settings.anthropic_api_key:
        client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        reader = ClaudePrescriptionReader(client, settings.reader_model, settings.reader_effort)
        app.state.prescription_service = PrescriptionService(reader, PrescriptionVerifier(matcher))
    else:
        logger.warning("ANTHROPIC_API_KEY is not set: prescription reading is disabled")
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    if settings.sentry_dsn:
        init_sentry(settings.sentry_dsn, settings.environment, __version__)
    app = FastAPI(title=settings.app_name, version=__version__, lifespan=lifespan)
    app.add_middleware(RequestIdMiddleware)
    app.include_router(health.router)
    app.include_router(drugs.router)
    app.include_router(prescriptions.router)
    app.include_router(schedules.router)
    return app


app = create_app()
