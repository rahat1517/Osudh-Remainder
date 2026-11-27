"""Gemini as the consent-only second reader: request shape, error mapping, routing, wiring."""

import base64
import io
import json

import httpx2
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.config import Settings
from app.drugs.models import Confidence
from app.main import app, build_reader
from app.prescriptions.errors import ReaderError
from app.prescriptions.gemini_reader import SCHEMA, GeminiPrescriptionReader, inline_refs
from app.prescriptions.images import prepare_image
from app.prescriptions.local_reader import HybridReader
from app.prescriptions.service import PrescriptionService
from app.prescriptions.verifier import PrescriptionVerifier

from .prescription_factories import extraction, image_bytes, medicine


def gemini(handler) -> GeminiPrescriptionReader:
    client = httpx2.Client(transport=httpx2.MockTransport(handler))
    return GeminiPrescriptionReader("test-key", "gemini-test", client)


def answer(result, **extra) -> httpx2.Response:
    parts = [{"text": "thinking...", "thought": True}, {"text": result.model_dump_json()}]
    return httpx2.Response(
        200, json={"candidates": [{"content": {"parts": parts}, "finishReason": "STOP", **extra}]}
    )


def test_schema_is_self_contained():
    assert "$ref" not in json.dumps(SCHEMA) and "$defs" not in SCHEMA
    assert inline_refs(
        {"$defs": {"A": {"type": "string"}}, "properties": {"a": {"$ref": "#/$defs/A"}}}
    ) == {"properties": {"a": {"type": "string"}}}


def test_reads_the_photo_with_json_output():
    expected = extraction(medicine())
    seen = []

    def handler(request):
        seen.append(request)
        return answer(expected)

    image = prepare_image(image_bytes())
    assert gemini(handler).read(image) == expected  # the "thought" part is ignored
    (request,) = seen
    assert request.url.path == "/v1beta/models/gemini-test:generateContent"
    assert request.headers["x-goog-api-key"] == "test-key"
    body = json.loads(request.content)
    inline = body["contents"][0]["parts"][0]["inlineData"]
    assert base64.b64decode(inline["data"]) == image.data
    config = body["generationConfig"]
    assert config["responseMimeType"] == "application/json"
    assert config["responseJsonSchema"] == SCHEMA
    assert config["temperature"] == 0


def test_models_without_schema_support_get_it_in_the_prompt():
    expected = extraction(medicine())
    bodies = []

    def handler(request):
        body = json.loads(request.content)
        bodies.append(body)
        if "responseJsonSchema" in body["generationConfig"]:
            return httpx2.Response(400, text="Unknown name responseJsonSchema")
        return answer(expected)

    assert gemini(handler).read(prepare_image(image_bytes())) == expected
    assert "schema" in bodies[1]["contents"][0]["parts"][1]["text"]


@pytest.mark.parametrize(
    ("response", "code", "retryable"),
    [
        (
            httpx2.Response(429, json={"error": {"status": "RESOURCE_EXHAUSTED"}}),
            "ai_rate_limited",
            True,
        ),
        (httpx2.Response(503, text="overloaded"), "ai_failed", True),
        (httpx2.Response(403, text="API key not valid"), "ai_failed", False),
        (
            httpx2.Response(200, json={"promptFeedback": {"blockReason": "SAFETY"}}),
            "ai_refused",
            False,
        ),
        (
            httpx2.Response(
                200, json={"candidates": [{"finishReason": "SAFETY", "content": {"parts": []}}]}
            ),
            "ai_refused",
            False,
        ),
        (
            httpx2.Response(
                200, json={"candidates": [{"finishReason": "MAX_TOKENS", "content": {"parts": []}}]}
            ),
            "prescription_too_long",
            False,
        ),
        (
            httpx2.Response(
                200, json={"candidates": [{"content": {"parts": [{"text": "not json"}]}}]}
            ),
            "ai_failed",
            True,
        ),
    ],
)
def test_errors_become_reader_errors(response, code, retryable):
    with pytest.raises(ReaderError) as e:
        gemini(lambda _: response).read(prepare_image(image_bytes()))
    assert (e.value.code, e.value.retryable) == (code, retryable)


def test_network_failure_is_retryable():
    def handler(request):
        raise httpx2.ConnectError("no route")

    with pytest.raises(ReaderError) as e:
        gemini(handler).read(prepare_image(image_bytes()))
    assert e.value.code == "ai_unavailable" and e.value.retryable


# --- Consent routing ----------------------------------------------------------------------------
class Stub:
    def __init__(self, result=None, error=None):
        self.result, self.error, self.images = result, error, []

    def read(self, image):
        self.images.append(image)
        if self.error:
            raise self.error
        return self.result


def test_cloud_reader_needing_consent_is_used_only_with_it_and_on_a_redacted_photo():
    image = prepare_image(image_bytes())
    unsure = extraction(medicine(name_confidence=Confidence.LOW))
    cloud_answer = extraction(medicine(name="Cloud"))
    local, cloud = Stub(unsure), Stub(cloud_answer)

    def redact(data: bytes) -> bytes:
        img = Image.open(io.BytesIO(data)).convert("RGB")
        img.paste((0, 0, 0), (0, 0, 10, 10))
        out = io.BytesIO()
        img.save(out, format="JPEG")
        return out.getvalue()

    hybrid = HybridReader(local, cloud, needs_consent=True, redact=redact)
    assert hybrid.read(image, allow_cloud=False) == unsure
    assert cloud.images == []
    assert hybrid.read(image, allow_cloud=True) == cloud_answer
    (sent,) = cloud.images
    assert sent.data != image.data and sent.media_type == "image/jpeg"
    assert dict(hybrid.routes) == {"local_no_consent": 1, "cloud_fallback": 1}


def test_a_failing_consent_only_cloud_reader_falls_back_to_the_local_reading():
    # e.g. the free daily quota is used up: the user still gets the own model's reading to check
    unsure = extraction(medicine(name_confidence=Confidence.LOW))
    hybrid = HybridReader(
        Stub(unsure),
        Stub(error=ReaderError("ai_rate_limited", "quota", retryable=True)),
        needs_consent=True,
    )
    assert hybrid.read(prepare_image(image_bytes()), allow_cloud=True) == unsure
    assert hybrid.routes["local_after_cloud_error"] == 1


def test_without_consent_a_local_failure_is_not_sent_to_the_cloud():
    cloud = Stub(extraction(medicine()))
    hybrid = HybridReader(
        Stub(error=ReaderError("ai_failed", "down", retryable=True)), cloud, needs_consent=True
    )
    with pytest.raises(ReaderError):
        hybrid.read(prepare_image(image_bytes()), allow_cloud=False)
    assert cloud.images == []


# --- Wiring -------------------------------------------------------------------------------------
def test_gemini_is_a_consent_only_second_reader_with_redaction():
    cloud = GeminiPrescriptionReader("k", "m")
    for mode in ("auto", "hybrid"):
        reader = build_reader(
            Settings(_env_file=None, reader_mode=mode), cloud, cloud_needs_consent=True
        )
        assert isinstance(reader, HybridReader)
        assert reader._needs_consent and reader._redact is not None
    with pytest.raises(RuntimeError):
        build_reader(Settings(_env_file=None, reader_mode="cloud"), cloud, cloud_needs_consent=True)


def test_the_app_sends_consent_with_each_scan():
    calls = []

    class Recording(HybridReader):
        def read(self, image, *, allow_cloud=True):
            calls.append(allow_cloud)
            return extraction(medicine())

    with TestClient(app) as client:
        app.state.prescription_service = PrescriptionService(
            Recording(Stub(), Stub(), needs_consent=True),
            PrescriptionVerifier(app.state.drug_matcher),
        )
        files = {"image": ("rx.jpg", image_bytes(), "image/jpeg")}
        assert client.post("/prescriptions/extract", files=files).status_code == 200
        assert (
            client.post(
                "/prescriptions/extract", files=files, data={"cloud_ok": "true"}
            ).status_code
            == 200
        )
    assert calls == [False, True]  # no consent unless the app says so


def test_next_model_is_tried_when_one_is_overloaded_or_retired():
    expected = extraction(medicine())
    tried = []

    def handler(request):
        model = request.url.path.split("/")[-1].split(":")[0]
        tried.append(model)
        if model == "busy":
            return httpx2.Response(503, json={"error": {"status": "UNAVAILABLE"}})
        if model == "old":
            return httpx2.Response(404, json={"error": {"status": "NOT_FOUND"}})
        return answer(expected)

    client = httpx2.Client(transport=httpx2.MockTransport(handler))
    reader = GeminiPrescriptionReader("k", "busy, old ,good", client)
    assert reader.models == ["busy", "old", "good"]
    assert reader.read(prepare_image(image_bytes())) == expected
    assert tried == ["busy", "old", "good"]


def test_the_last_models_error_is_reported():
    client = httpx2.Client(
        transport=httpx2.MockTransport(lambda r: httpx2.Response(503, text="high demand"))
    )
    with pytest.raises(ReaderError) as e:
        GeminiPrescriptionReader("k", "a,b", client).read(prepare_image(image_bytes()))
    assert e.value.code == "ai_failed" and e.value.retryable


def test_available_models_lists_generate_content_models_and_never_raises():
    models = {
        "models": [
            {"name": "models/gemini-x-flash", "supportedGenerationMethods": ["generateContent"]},
            {"name": "models/embedding-y", "supportedGenerationMethods": ["embedContent"]},
        ]
    }
    ok = httpx2.Client(transport=httpx2.MockTransport(lambda r: httpx2.Response(200, json=models)))
    assert GeminiPrescriptionReader("k", "m", ok).available_models() == ["gemini-x-flash"]
    down = httpx2.Client(transport=httpx2.MockTransport(lambda r: httpx2.Response(500)))
    assert GeminiPrescriptionReader("k", "m", down).available_models() == []
