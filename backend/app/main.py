import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app import __version__
from app.api import drugs, health
from app.config import get_settings
from app.drugs.catalog import load_csv
from app.drugs.matcher import DrugMatcher

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    catalog, report = load_csv(settings.drugs_csv_path)
    for err in report.errors:
        logger.warning("ওষুধের তালিকায় ত্রুটি: %s", err)
    app.state.drug_matcher = DrugMatcher(catalog)
    logger.info("%d টা ওষুধ লোড হয়েছে", len(catalog))
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version=__version__, lifespan=lifespan)
    app.include_router(health.router)
    app.include_router(drugs.router)
    return app


app = create_app()
