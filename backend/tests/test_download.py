"""Public download page."""

import pytest
from fastapi.testclient import TestClient

from app.api import download
from app.config import Settings, get_settings
from app.main import create_app

MANIFEST = {
    "build": 10,
    "apks": {
        "arm64-v8a": "https://x.supabase.co/a/10/oshudh-reminder-arm64-v8a.apk",
        "armeabi-v7a": "https://x.supabase.co/a/10/oshudh-reminder-armeabi-v7a.apk",
    },
}


@pytest.fixture
def client(monkeypatch):
    app = create_app()
    app.dependency_overrides[get_settings] = lambda: Settings(
        _env_file=None, supabase_url="https://x.supabase.co"
    )
    download._CACHE.update(at=0.0, manifest=None)
    return TestClient(app)


def test_page_offers_the_newest_build_to_anyone(client, monkeypatch):
    monkeypatch.setattr(download, "fetch_manifest", lambda s: MANIFEST)
    r = client.get("/download")  # no sign-in, no GitHub account
    assert r.status_code == 200
    assert "ডাউনলোড করুন" in r.text
    assert MANIFEST["apks"]["arm64-v8a"] in r.text
    assert MANIFEST["apks"]["armeabi-v7a"] in r.text
    assert "সংস্করণ 10" in r.text


def test_short_link_redirects_to_the_apk(client, monkeypatch):
    monkeypatch.setattr(download, "fetch_manifest", lambda s: MANIFEST)
    r = client.get("/download/apk", follow_redirects=False)
    assert r.status_code == 302
    assert r.headers["location"] == MANIFEST["apks"]["arm64-v8a"]


def test_without_a_build_the_page_says_so(client, monkeypatch):
    monkeypatch.setattr(download, "fetch_manifest", lambda s: None)
    assert "এখন ডাউনলোড পাওয়া যাচ্ছে না" in client.get("/download").text
    assert client.get("/download/apk", follow_redirects=False).headers["location"] == "/download"


def test_manifest_is_fetched_once_a_minute_and_survives_outages(monkeypatch):
    calls = []

    class Resp:
        def raise_for_status(self):
            pass

        def json(self):
            return MANIFEST

    def fake_get(url, timeout):
        calls.append(url)
        if len(calls) > 1:
            raise download.httpx2.ConnectError("down")
        return Resp()

    monkeypatch.setattr(download.httpx2, "get", fake_get)
    download._CACHE.update(at=0.0, manifest=None)
    s = Settings(_env_file=None, supabase_url="https://x.supabase.co")
    assert download.fetch_manifest(s) == MANIFEST
    assert download.fetch_manifest(s) == MANIFEST  # cached
    assert len(calls) == 1
    download._CACHE["at"] = 0.0  # cache expired, storage down: keep the last good one
    assert download.fetch_manifest(s) == MANIFEST
    assert calls[0].endswith("/storage/v1/object/public/app-releases/latest.json")
