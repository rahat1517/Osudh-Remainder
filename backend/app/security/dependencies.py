"""FastAPI dependencies for authentication and rate limiting."""

from typing import Annotated

from fastapi import Depends, Request, status

from app.api.errors import api_error
from app.security.auth import ANONYMOUS, AuthError, User
from app.security.rate_limit import RateLimited


def current_user(request: Request) -> User:
    verifier = request.app.state.token_verifier
    if verifier is None:
        # Authentication disabled (local development only; refused in production at startup)
        return ANONYMOUS
    header = request.headers.get("authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise api_error(status.HTTP_401_UNAUTHORIZED, "auth_required", "Sign in required")
    try:
        return verifier.verify(token)
    except AuthError as e:
        raise api_error(status.HTTP_401_UNAUTHORIZED, e.code, e.message) from e


CurrentUser = Annotated[User, Depends(current_user)]


def limit_ai_requests(request: Request, user: CurrentUser) -> User:
    """Per-user limit on the costly AI endpoint (per client IP when auth is disabled)."""
    key = (
        user.id if not user.is_anonymous else f"ip:{request.client.host if request.client else '?'}"
    )
    try:
        request.app.state.ai_rate_limiter.check(key)
    except RateLimited as e:
        raise api_error(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "rate_limited",
            "Too many requests",
            retry_after=e.retry_after,
        ) from e
    return user


AiUser = Annotated[User, Depends(limit_ai_requests)]
