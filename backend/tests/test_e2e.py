"""End-to-end API flow with authentication: read a prescription, confirm it, schedule it."""

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.prescriptions.schemas import Timing
from app.prescriptions.service import PrescriptionService
from app.prescriptions.verifier import PrescriptionVerifier
from app.security.auth import TokenVerifier
from app.security.rate_limit import SlidingWindowLimiter

from .prescription_factories import M, extraction, image_bytes, medicine
from .test_security import SECRET, token


class _Reader:
    def read(self, image):
        return extraction(
            medicine(),  # Seclo 20 mg, 1+0+1 before meals, 30 days
            medicine(
                raw_text="Tab. Napa 500mg 1+1+1 PC 5 days",
                name="Nappa",  # misspelled by the doctor
                name_confidence=M,
                strength="500 mg",
                dose_pattern="1+1+1",
                timing=Timing.AFTER_MEAL,
                duration_days=5,
            ),
        )


@pytest.fixture
def client():
    with TestClient(app) as c:
        app.state.token_verifier = TokenVerifier(jwt_secret=SECRET)
        app.state.ai_rate_limiter = SlidingWindowLimiter([(10, 60)])
        app.state.prescription_service = PrescriptionService(
            _Reader(), PrescriptionVerifier(app.state.drug_matcher)
        )
        yield c
        app.state.token_verifier = None


def test_read_confirm_schedule(client):
    auth = {"Authorization": f"Bearer {token('patient-1')}"}

    # 1. Read the prescription
    r = client.post(
        "/prescriptions/extract",
        files={"image": ("rx.jpg", image_bytes(), "image/jpeg")},
        headers=auth,
    )
    assert r.status_code == 200
    scan = r.json()
    assert scan["requires_confirmation"] is True
    seclo, napa = scan["medicines"]
    assert (seclo["name"]["value"], seclo["name"]["confidence"]) == ("Seclo", "high")
    # The misspelling was matched but must be reviewed by the user
    assert (napa["name"]["value"], napa["name"]["confidence"]) == ("Napa", "medium")
    assert napa["name"]["note"]["code"] == "name_corrected"

    # 2. The user reviews and confirms; the app sends the confirmed values for scheduling
    confirmed = [
        {
            "id": "seclo",
            "dose_pattern": seclo["dose"]["value"],
            "timing": seclo["timing"]["value"],
            "duration_days": seclo["duration"]["value"]["days"],
        },
        {
            "id": "napa",
            "dose_pattern": napa["dose"]["value"],
            "timing": napa["timing"]["value"],
            "duration_days": napa["duration"]["value"]["days"],
        },
    ]
    r = client.post(
        "/schedules/generate",
        json={"start": "2026-11-26T10:00:00+06:00", "days": 1, "medicines": confirmed},
        headers=auth,
    )
    assert r.status_code == 200
    body = r.json()

    # 3. Reminders for the next 24 hours from 10:00: Napa after lunch, Seclo before dinner,
    #    Napa after dinner, then tomorrow morning's Seclo (before) and Napa (after breakfast)
    reminders = [(x["at"][5:16], [i["medicine_id"] for i in x["items"]]) for x in body["reminders"]]
    assert reminders == [
        ("11-26T13:45", ["napa"]),
        ("11-26T21:00", ["seclo"]),
        ("11-26T21:45", ["napa"]),
        ("11-27T07:30", ["seclo"]),
        ("11-27T08:15", ["napa"]),
    ]
    totals = {m["medicine_id"]: m["total_doses"] for m in body["medicines"]}
    assert totals == {"seclo": 60, "napa": 15}
