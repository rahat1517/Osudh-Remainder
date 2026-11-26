import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import anthropic
from fastapi import FastAPI

from app import __version__
from app.api import drugs, health, prescriptions
from app.config import get_settings
from app.drugs.catalog import load_csv
from app.drugs.matcher import DrugMatcher
from app.prescriptions.reader import ClaudePrescriptionReader
from app.prescriptions.service import PrescriptionService
from app.prescriptions.verifier import PrescriptionVerifier

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    catalog, report = load_csv(settings.drugs_csv_path)
    for err in report.errors:
        logger.warning("ওষুধের তালিকায় ত্রুটি: %s", err)
    matcher = DrugMatcher(catalog)
    app.state.drug_matcher = matcher
    logger.info("%d টা ওষুধ লোড হয়েছে", len(catalog))

    app.state.prescription_service = None
    if settings.anthropic_api_key:
        client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        reader = ClaudePrescriptionReader(client, settings.reader_model, settings.reader_effort)
        app.state.prescription_service = PrescriptionService(reader, PrescriptionVerifier(matcher))
    else:
        logger.warning("ANTHROPIC_API_KEY নেই: প্রেসক্রিপশন পড়া বন্ধ থাকবে")
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version=__version__, lifespan=lifespan)
    app.include_router(health.router)
    app.include_router(drugs.router)
    app.include_router(prescriptions.router)
    return app


app = create_app()
