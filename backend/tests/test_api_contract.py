"""Contract test: spec/api/examples/prescription_result.json is a real response of
POST /prescriptions/extract. The app's tests parse the same file, so a change to the response
shape breaks one side or the other in CI.

Regenerate after an intended change:  UPDATE_CONTRACT=1 uv run pytest tests/test_api_contract.py
"""

import json
import os
from pathlib import Path

from fastapi.testclient import TestClient

from app.main import app
from app.prescriptions.schemas import ImageQuality, Timing
from app.prescriptions.service import PrescriptionService
from app.prescriptions.verifier import PrescriptionVerifier

from .prescription_factories import M, extraction, image_bytes, medicine

EXAMPLE = Path(__file__).parents[2] / "spec" / "api" / "examples" / "prescription_result.json"


class _Reader:
    def read(self, image):
        return extraction(
            medicine(),
            medicine(
                raw_text="Tab. Sargel 20mg 1+0+1 AC 14 days",
                name="Sargel",
                name_confidence=M,
                dose_pattern="1+0+1",
                duration_days=14,
                duration_raw="14 days",
            ),
            medicine(
                raw_text="Tab. Napa Extend SOS",
                name="Napa Extend",
                strength=None,
                dose_pattern=None,
                dose_raw="SOS",
                timing=Timing.NOT_SPECIFIED,
                duration_days=None,
                duration_raw=None,
                as_needed=True,
            ),
            quality=ImageQuality.READABLE_WITH_EFFORT,
        )


def test_prescription_result_example_is_current():
    with TestClient(app) as client:
        app.state.prescription_service = PrescriptionService(
            _Reader(), PrescriptionVerifier(app.state.drug_matcher)
        )
        files = {"image": ("rx.jpg", image_bytes(), "image/jpeg")}
        response = client.post("/prescriptions/extract", files=files)
    assert response.status_code == 200
    actual = json.dumps(response.json(), ensure_ascii=False, indent=2) + "\n"
    if os.environ.get("UPDATE_CONTRACT"):
        EXAMPLE.write_text(actual, encoding="utf-8")
    assert EXAMPLE.read_text(encoding="utf-8") == actual, (
        "Response shape changed; run with UPDATE_CONTRACT=1 and update the app"
    )
