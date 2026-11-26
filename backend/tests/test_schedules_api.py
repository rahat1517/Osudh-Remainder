import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


def test_generate_schedule(client):
    r = client.post(
        "/schedules/generate",
        json={
            "start": "2026-11-26T07:00:00",
            "days": 2,
            "medicines": [
                {
                    "id": "seclo",
                    "dose_pattern": "1+0+1",
                    "timing": "before_meal",
                    "duration_days": 30,
                },
                {"id": "napa", "dose_pattern": "1+1+1", "timing": "after_meal", "duration_days": 5},
            ],
        },
    )
    assert r.status_code == 200
    body = r.json()
    assert body["timezone"] == "Asia/Dhaka"
    seclo = body["medicines"][0]
    assert seclo["total_doses"] == 60
    assert seclo["first_dose_at"] == "2026-11-26T07:30:00+06:00"
    assert [x["at"] for x in body["reminders"]][:2] == [
        "2026-11-26T07:30:00+06:00",
        "2026-11-26T08:15:00+06:00",
    ]


def test_timezone_aware_start_is_converted(client):
    r = client.post(
        "/schedules/generate",
        json={
            "start": "2026-11-26T01:00:00Z",  # 07:00 in Dhaka
            "days": 1,
            "medicines": [
                {"id": "m", "dose_pattern": "1+0+0", "timing": "before_meal", "duration_days": 1}
            ],
        },
    )
    assert r.json()["reminders"][0]["at"] == "2026-11-26T07:30:00+06:00"


def test_invalid_dose_returns_error_code(client):
    r = client.post(
        "/schedules/generate",
        json={
            "start": "2026-11-26T07:00:00",
            "medicines": [{"id": "bad", "dose_pattern": "10+0+10", "duration_days": 5}],
        },
    )
    assert r.status_code == 422
    assert r.json()["detail"] == {
        "code": "invalid_dose_pattern",
        "message": "Cannot use dose pattern '10+0+10'",
        "medicine_id": "bad",
    }


def test_window_is_limited(client):
    r = client.post(
        "/schedules/generate",
        json={
            "start": "2026-11-26T07:00:00",
            "days": 90,
            "medicines": [{"id": "m", "duration_days": 1}],
        },
    )
    assert r.status_code == 422
