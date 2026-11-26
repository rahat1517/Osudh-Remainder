import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.prescriptions.reader import ReaderError
from app.prescriptions.service import PrescriptionService
from app.prescriptions.verifier import PrescriptionVerifier

from .prescription_factories import extraction, image_bytes, medicine


class FakeReader:
    def __init__(self, result=None, error=None):
        self.result, self.error = result, error

    def read(self, image):
        if self.error:
            raise self.error
        return self.result


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def use_reader(reader):
    app.state.prescription_service = PrescriptionService(
        reader, PrescriptionVerifier(app.state.drug_matcher)
    )


def post_image(client, data=None):
    files = {"image": ("rx.jpg", data or image_bytes(), "image/jpeg")}
    return client.post("/prescriptions/extract", files=files)


def test_without_api_key_returns_503(client):
    app.state.prescription_service = None
    r = post_image(client)
    assert r.status_code == 503


def test_extract_success(client):
    use_reader(FakeReader(extraction(medicine())))
    r = post_image(client)
    assert r.status_code == 200
    body = r.json()
    assert body["requires_confirmation"] is True
    assert body["medicines"][0]["name"] == {"value": "Seclo", "confidence": "high", "note": None}
    assert body["medicines"][0]["dose"]["value"] == "1+0+1"


def test_not_a_prescription(client):
    use_reader(FakeReader(extraction(is_rx=False)))
    r = post_image(client)
    assert r.status_code == 422
    assert "প্রেসক্রিপশন" in r.json()["detail"]


def test_bad_image(client):
    use_reader(FakeReader(extraction()))
    assert post_image(client, b"not an image").status_code == 422


@pytest.mark.parametrize(("retryable", "code"), [(True, 503), (False, 502)])
def test_reader_errors(client, retryable, code):
    use_reader(FakeReader(error=ReaderError("x", "বার্তা", retryable)))
    r = post_image(client)
    assert r.status_code == code
    assert r.json()["detail"] == "বার্তা"
