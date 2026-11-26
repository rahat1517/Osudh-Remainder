"""Uniform error responses: `{"detail": {"code": ..., "message": ...}}`.

`code` is stable and documented; clients localize it. `message` is English, for developers.
"""

from fastapi import HTTPException


def api_error(status_code: int, code: str, message: str, **extra: object) -> HTTPException:
    return HTTPException(status_code, detail={"code": code, "message": message, **extra})
