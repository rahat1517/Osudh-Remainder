"""SMS and voice-call providers.

Bangladeshi providers (e.g. BulkSMSBD, SSL Wireless, Alpha SMS) expose simple HTTP APIs that
differ in field names. `HttpSmsGateway` targets the common "api_key / senderid / number / message"
form; write a small adapter with the same interface for another provider. Voice-call (IVR)
providers usually accept a number and a text-to-speech script or audio URL; `HttpVoiceGateway`
sends JSON {to, language, text}.
"""

import logging
from dataclasses import dataclass
from typing import Protocol

import httpx2

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class SendResult:
    ok: bool
    provider_id: str | None = None
    error: str | None = None


class SmsGateway(Protocol):
    def send_sms(self, to: str, text: str) -> SendResult: ...


class VoiceGateway(Protocol):
    def place_call(self, to: str, text: str, language: str) -> SendResult: ...


def local_number(e164: str) -> str:
    """+8801712345678 → 8801712345678 (the form most Bangladeshi gateways expect)."""
    return e164.lstrip("+")


class HttpSmsGateway:
    def __init__(self, url: str, api_key: str, sender_id: str, client: httpx2.Client | None = None):
        self._url, self._key, self._sender = url, api_key, sender_id
        self._client = client or httpx2.Client(timeout=20)

    def send_sms(self, to: str, text: str) -> SendResult:
        try:
            r = self._client.post(
                self._url,
                data={
                    "api_key": self._key,
                    "senderid": self._sender,
                    "number": local_number(to),
                    "message": text,
                },
            )
        except httpx2.HTTPError as e:
            return SendResult(False, error=f"network: {e}")
        if r.status_code >= 300:
            return SendResult(False, error=f"HTTP {r.status_code}")
        try:
            body = r.json()
        except ValueError:
            body = {}
        code = str(body.get("response_code", body.get("status", "")))
        ok = code in {"202", "200", "success", "SUCCESS", ""}
        provider_id = str(body.get("message_id") or body.get("id") or "") or None
        return SendResult(ok, provider_id, None if ok else f"provider: {body}")


class HttpVoiceGateway:
    def __init__(self, url: str, api_key: str, client: httpx2.Client | None = None):
        self._url, self._key = url, api_key
        self._client = client or httpx2.Client(timeout=20)

    def place_call(self, to: str, text: str, language: str) -> SendResult:
        try:
            r = self._client.post(
                self._url,
                headers={"Authorization": f"Bearer {self._key}"},
                json={"to": local_number(to), "language": language, "text": text},
            )
        except httpx2.HTTPError as e:
            return SendResult(False, error=f"network: {e}")
        if r.status_code >= 300:
            return SendResult(False, error=f"HTTP {r.status_code}")
        return SendResult(True, str(r.json().get("id", "")) or None)


class RecordingGateway:
    """Collects messages instead of sending them (tests, dry runs)."""

    def __init__(self, fail: bool = False):
        self.sms: list[tuple[str, str]] = []
        self.calls: list[tuple[str, str, str]] = []
        self._fail = fail

    def send_sms(self, to: str, text: str) -> SendResult:
        self.sms.append((to, text))
        return SendResult(not self._fail, "rec-sms", "failed" if self._fail else None)

    def place_call(self, to: str, text: str, language: str) -> SendResult:
        self.calls.append((to, text, language))
        return SendResult(not self._fail, "rec-call", "failed" if self._fail else None)
