"""Push notifications (Firebase Cloud Messaging HTTP v1)."""

import json
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Protocol

import httpx2

logger = logging.getLogger(__name__)

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


@dataclass(frozen=True)
class PushMessage:
    token: str
    title: str
    body: str
    data: dict[str, str] = field(default_factory=dict)


class Notifier(Protocol):
    def send(self, messages: list[PushMessage]) -> list[str]:
        """Sends messages; returns tokens that are no longer valid (to be deleted)."""
        ...


class FcmNotifier:
    def __init__(self, service_account_file: Path, client: httpx2.Client | None = None):
        from google.oauth2 import service_account  # imported lazily: only needed in production

        info = json.loads(service_account_file.read_text(encoding="utf-8"))
        self._project = info["project_id"]
        self._credentials = service_account.Credentials.from_service_account_info(
            info, scopes=[FCM_SCOPE]
        )
        self._client = client or httpx2.Client(timeout=15)

    def _token(self) -> str:
        from google.auth.transport.requests import Request

        if not self._credentials.valid:
            self._credentials.refresh(Request())
        return self._credentials.token

    def send(self, messages: list[PushMessage]) -> list[str]:
        url = f"https://fcm.googleapis.com/v1/projects/{self._project}/messages:send"
        invalid: list[str] = []
        for m in messages:
            body = {
                "message": {
                    "token": m.token,
                    "notification": {"title": m.title, "body": m.body},
                    "data": m.data,
                    "android": {
                        "priority": "high",
                        "notification": {"channel_id": "caregiver_alerts"},
                    },
                }
            }
            r = self._client.post(
                url, json=body, headers={"Authorization": f"Bearer {self._token()}"}
            )
            # FCM answers 404/UNREGISTERED for uninstalled apps and 400 for malformed tokens
            unregistered = r.status_code == 404 or "UNREGISTERED" in r.text
            malformed = r.status_code == 400 and "registration token" in r.text.lower()
            if unregistered or malformed:
                invalid.append(m.token)
            elif r.status_code >= 300:
                logger.error("FCM send failed: %s %s", r.status_code, r.text[:200])
        return invalid


class RecordingNotifier:
    """Keeps messages in memory (tests, dry runs)."""

    def __init__(self, invalid_tokens: set[str] | None = None):
        self.sent: list[PushMessage] = []
        self._invalid = invalid_tokens or set()

    def send(self, messages: list[PushMessage]) -> list[str]:
        self.sent.extend(messages)
        return [m.token for m in messages if m.token in self._invalid]
