import time
from types import SimpleNamespace

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import app, build_token_verifier
from app.observability import scrub_event
from app.prescriptions.service import PrescriptionService
from app.prescriptions.verifier import PrescriptionVerifier
from app.security.auth import AuthError, TokenVerifier
from app.security.rate_limit import RateLimited, SlidingWindowLimiter

from .prescription_factories import extraction, image_bytes, medicine

SECRET = "test-secret-with-at-least-32-characters!!"
EC_KEY = ec.generate_private_key(ec.SECP256R1())


class FakeJwks:
    def get_signing_key_from_jwt(self, token):
        return SimpleNamespace(key=EC_KEY.public_key())


def token(sub="user-1", *, alg="HS256", exp_in=3600, aud="authenticated", key=None, iss=None):
    claims = {"sub": sub, "aud": aud, "role": "authenticated", "exp": int(time.time()) + exp_in}
    if iss:
        claims["iss"] = iss
    signing_key = key or (SECRET if alg == "HS256" else EC_KEY)
    return jwt.encode(claims, signing_key, algorithm=alg)


@pytest.fixture
def verifier():
    return TokenVerifier(jwt_secret=SECRET, jwks_client=FakeJwks())


def test_accepts_hs256_and_es256(verifier):
    assert verifier.verify(token(alg="HS256")).id == "user-1"
    assert verifier.verify(token(alg="ES256")).id == "user-1"


@pytest.mark.parametrize(
    "bad",
    [
        lambda: token(exp_in=-10),
        lambda: token(aud="anon"),
        lambda: token(key="another-secret-another-secret-123456"),
        lambda: token(alg="ES256", key=ec.generate_private_key(ec.SECP256R1())),
        lambda: "not-a-jwt",
    ],
)
def test_rejects_bad_tokens(verifier, bad):
    with pytest.raises(AuthError) as exc:
        verifier.verify(bad())
    assert exc.value.code == "auth_invalid"


def test_only_configured_algorithms_are_accepted():
    with pytest.raises(AuthError):
        TokenVerifier(jwks_client=FakeJwks()).verify(token(alg="HS256"))
    with pytest.raises(AuthError):
        TokenVerifier(jwt_secret=SECRET).verify(token(alg="ES256"))


def test_issuer_is_checked_when_configured():
    v = TokenVerifier(jwt_secret=SECRET, issuer="https://x.supabase.co/auth/v1")
    assert v.verify(token(iss="https://x.supabase.co/auth/v1")).id == "user-1"
    with pytest.raises(AuthError):
        v.verify(token(iss="https://evil.example/auth/v1"))


def test_production_refuses_to_start_without_auth():
    with pytest.raises(RuntimeError):
        build_token_verifier(Settings(environment="production", _env_file=None))
    assert build_token_verifier(Settings(environment="development", _env_file=None)) is None
    built = build_token_verifier(
        Settings(environment="production", supabase_url="https://x.supabase.co", _env_file=None)
    )
    assert isinstance(built, TokenVerifier)


def test_sliding_window_limiter():
    now = [0.0]
    limiter = SlidingWindowLimiter([(2, 60), (3, 3600)], clock=lambda: now[0])
    limiter.check("a")
    limiter.check("a")
    with pytest.raises(RateLimited) as exc:
        limiter.check("a")
    assert exc.value.retry_after == 61
    limiter.check("b")  # other users are unaffected
    now[0] = 61
    limiter.check("a")  # minute window passed
    now[0] = 130
    with pytest.raises(RateLimited):
        limiter.check("a")  # hourly limit of 3 reached


def test_error_reports_are_scrubbed():
    event = {
        "request": {
            "data": "image bytes",
            "query_string": "q=seclo",
            "cookies": {"s": "1"},
            "headers": {"Authorization": "Bearer abc", "User-Agent": "app"},
        },
        "user": {"id": "u1"},
    }
    scrubbed = scrub_event(event)
    assert "data" not in scrubbed["request"]
    assert "query_string" not in scrubbed["request"]
    assert scrubbed["request"]["headers"]["Authorization"] == "[removed]"
    assert scrubbed["request"]["headers"]["User-Agent"] == "app"
    assert "user" not in scrubbed


class _Reader:
    def read(self, image):
        return extraction(medicine())


@pytest.fixture
def client(verifier):
    with TestClient(app) as c:
        app.state.token_verifier = verifier
        app.state.ai_rate_limiter = SlidingWindowLimiter([(2, 60)])
        app.state.prescription_service = PrescriptionService(
            _Reader(), PrescriptionVerifier(app.state.drug_matcher)
        )
        yield c
        app.state.token_verifier = None


def _extract(client, headers=None):
    files = {"image": ("rx.jpg", image_bytes(), "image/jpeg")}
    return client.post("/prescriptions/extract", files=files, headers=headers or {})


def test_endpoints_require_a_token(client):
    assert _extract(client).json()["detail"]["code"] == "auth_required"
    bad = _extract(client, {"Authorization": "Bearer nonsense"})
    assert (bad.status_code, bad.json()["detail"]["code"]) == (401, "auth_invalid")
    r = client.post(
        "/schedules/generate",
        json={"start": "2026-11-26T07:00:00", "medicines": [{"id": "m", "duration_days": 1}]},
    )
    assert r.status_code == 401
    assert client.get("/drugs/search", params={"q": "napa"}).status_code == 200  # public data
    assert client.get("/health").status_code == 200


def test_ai_endpoint_is_rate_limited_per_user(client):
    alice = {"Authorization": f"Bearer {token('alice')}"}
    bob = {"Authorization": f"Bearer {token('bob', alg='ES256')}"}
    assert _extract(client, alice).status_code == 200
    assert _extract(client, alice).status_code == 200
    limited = _extract(client, alice)
    assert limited.status_code == 429
    assert limited.json()["detail"]["code"] == "rate_limited"
    assert int(limited.headers["Retry-After"]) > 0
    assert _extract(client, bob).status_code == 200


def test_request_id_is_returned(client):
    r = client.get("/health", headers={"X-Request-ID": "abc12345-from-app"})
    assert r.headers["X-Request-ID"] == "abc12345-from-app"
    assert len(client.get("/health").headers["X-Request-ID"]) == 32
