"""Uniform error responses: `{"detail": {"code": ..., "message": ...}}`.

`code` is stable and documented; clients localize it. `message` is English, for developers.
"""

from fastapi import HTTPException


def api_error(
    status_code: int,
    code: str,
    message: str,
    *,
    headers: dict[str, str] | None = None,
    **extra: object,
) -> HTTPException:
    if code == "rate_limited" and "retry_after" in extra:
        headers = {**(headers or {}), "Retry-After": str(extra["retry_after"])}
    return HTTPException(
        status_code, detail={"code": code, "message": message, **extra}, headers=headers
    )
