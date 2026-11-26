import base64
from types import SimpleNamespace

import anthropic
import httpx2
import pytest

from app.prescriptions.images import prepare_image
from app.prescriptions.reader import ClaudePrescriptionReader, ReaderError
from app.prescriptions.schemas import PrescriptionExtraction

from .prescription_factories import extraction, image_bytes, medicine


class FakeMessages:
    def __init__(self, result=None, error=None):
        self.result, self.error, self.calls = result, error, []

    def parse(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise self.error
        return self.result


def fake_client(messages: FakeMessages):
    return SimpleNamespace(beta=SimpleNamespace(messages=messages))


def response(parsed=None, stop_reason="end_turn"):
    return SimpleNamespace(
        parsed_output=parsed,
        stop_reason=stop_reason,
        stop_details=None,
        model="claude-opus-5-5",
        _request_id="req_test",
    )


def api_error(cls, status):
    req = httpx2.Request("POST", "https://api.anthropic.com/v1/messages")
    return cls("error", response=httpx2.Response(status, request=req), body=None)


@pytest.fixture
def image():
    return prepare_image(image_bytes())


def test_success_sends_image_and_schema(image):
    expected = extraction(medicine())
    messages = FakeMessages(result=response(expected))
    reader = ClaudePrescriptionReader(fake_client(messages), "claude-opus-5-5", "high")

    assert reader.read(image) == expected

    call = messages.calls[0]
    assert call["model"] == "claude-opus-5-5"
    assert call["output_format"] is PrescriptionExtraction
    assert call["output_config"] == {"effort": "high"}
    assert call["fallbacks"] == "default"
    block = call["messages"][0]["content"][0]
    assert block["type"] == "image"
    assert base64.standard_b64decode(block["source"]["data"]) == image.data
    assert "temperature" not in call  # নতুন API-তে বাতিল


@pytest.mark.parametrize(
    ("result", "retryable"),
    [
        (response(stop_reason="refusal"), False),
        (response(stop_reason="max_tokens"), False),
        (response(parsed=None), True),
    ],
)
def test_bad_responses_raise_reader_error(image, result, retryable):
    reader = ClaudePrescriptionReader(fake_client(FakeMessages(result=result)), "m")
    with pytest.raises(ReaderError) as exc:
        reader.read(image)
    assert exc.value.retryable is retryable
    assert exc.value.user_message  # অ্যাপে দেখানোর মতো বাংলা বার্তা


@pytest.mark.parametrize(
    ("error", "retryable"),
    [
        (api_error(anthropic.RateLimitError, 429), True),
        (api_error(anthropic.InternalServerError, 500), True),
        (api_error(anthropic.BadRequestError, 400), False),
        (anthropic.APIConnectionError(request=httpx2.Request("POST", "https://x")), True),
    ],
)
def test_api_errors_raise_reader_error(image, error, retryable):
    reader = ClaudePrescriptionReader(fake_client(FakeMessages(error=error)), "m")
    with pytest.raises(ReaderError) as exc:
        reader.read(image)
    assert exc.value.retryable is retryable
