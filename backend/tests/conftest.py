from pathlib import Path

import pytest

from app.config import get_settings
from app.drugs.catalog import load_csv
from app.drugs.matcher import DrugMatcher


@pytest.fixture(scope="session")
def matcher() -> DrugMatcher:
    drugs, report = load_csv(get_settings().drugs_csv_path)
    assert not report.errors
    return DrugMatcher(drugs)


@pytest.fixture
def fixtures_dir() -> Path:
    return Path(__file__).parent / "fixtures"
