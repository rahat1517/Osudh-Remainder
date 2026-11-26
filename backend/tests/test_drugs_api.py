import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:  # lifespan চালু করে ওষুধের তালিকা লোড করে
        yield c


def test_search(client):
    r = client.get("/drugs/search", params={"q": "maxp"})
    assert r.status_code == 200
    assert r.json()[0]["drug"]["brand"] == "Maxpro"


def test_search_requires_query(client):
    assert client.get("/drugs/search").status_code == 422


def test_match(client):
    r = client.post("/drugs/match", json={"text": "Tab. Sec1o 20mg"})
    assert r.status_code == 200
    body = r.json()
    assert body["best"]["drug"]["brand"] == "Seclo"
    assert body["best"]["drug"]["strength"] == "20 mg"
    assert body["confidence"] in {"high", "medium"}


def test_match_rejects_empty_text(client):
    assert client.post("/drugs/match", json={"text": ""}).status_code == 422


def test_get_drug(client):
    assert client.get("/drugs/1").json()["brand"] == "Napa"
    assert client.get("/drugs/99999").status_code == 404
