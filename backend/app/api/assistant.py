from fastapi import APIRouter, Request, status
from fastapi.concurrency import run_in_threadpool

from app.api.errors import api_error
from app.assistant.models import ChatRequest, ChatResponse
from app.assistant.safety import detect_emergency, emergency_response
from app.security.dependencies import CurrentUser
from app.security.rate_limit import RateLimited

router = APIRouter(prefix="/assistant", tags=["assistant"])


@router.post("/chat")
async def chat(body: ChatRequest, request: Request, user: CurrentUser) -> ChatResponse:
    """One assistant turn.

    Emergencies are answered by fixed rules first, so they work even when the AI is unavailable.
    Proposed changes come back as `actions`; the app must show them for confirmation.
    """
    latest = body.messages[-1]
    if latest.role == "user" and (kind := detect_emergency(latest.text)):
        return ChatResponse(
            reply=emergency_response(kind, body.context.locale), emergency=kind.value
        )

    service = request.app.state.assistant_service
    if service is None:
        raise api_error(
            status.HTTP_503_SERVICE_UNAVAILABLE, "ai_not_configured", "Assistant is not configured"
        )
    key = (
        user.id if not user.is_anonymous else f"ip:{request.client.host if request.client else '?'}"
    )
    try:
        request.app.state.assistant_rate_limiter.check(key)
    except RateLimited as e:
        raise api_error(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "rate_limited",
            "Too many messages",
            retry_after=e.retry_after,
        ) from e
    return await run_in_threadpool(service.chat, body)
