"""Error monitoring and request IDs, without personal data."""

import logging
import uuid
from typing import Any

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger(__name__)

_SENSITIVE_HEADERS = {"authorization", "cookie", "x-api-key"}


def scrub_event(event: dict[str, Any], _hint: dict[str, Any] | None = None) -> dict[str, Any]:
    """Removes data that could identify a patient before an error report leaves the server."""
    request = event.get("request") or {}
    request.pop("data", None)  # bodies may contain prescription images or medicine names
    request.pop("cookies", None)
    request.pop("query_string", None)  # may contain medicine names
    headers = request.get("headers") or {}
    for name in list(headers):
        if name.lower() in _SENSITIVE_HEADERS:
            headers[name] = "[removed]"
    event.pop("user", None)
    return event


def init_sentry(dsn: str, environment: str, release: str) -> None:
    import sentry_sdk

    sentry_sdk.init(
        dsn=dsn,
        environment=environment,
        release=release,
        send_default_pii=False,
        traces_sample_rate=0.0,
        before_send=scrub_event,
    )


class RequestIdMiddleware(BaseHTTPMiddleware):
    """Accepts or assigns an X-Request-ID and returns it, so app reports can be traced in logs."""

    async def dispatch(self, request: Request, call_next) -> Response:
        incoming = request.headers.get("x-request-id", "")
        request_id = (
            incoming if 8 <= len(incoming) <= 64 and incoming.isascii() else uuid.uuid4().hex
        )
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response
