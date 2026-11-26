import json
from typing import Annotated

from fastapi import APIRouter, File, Form, Request, UploadFile, status
from fastapi.concurrency import run_in_threadpool
from pydantic import ValidationError

from app.api.errors import api_error
from app.prescriptions.errors import ImageError
from app.prescriptions.images import MAX_UPLOAD_BYTES
from app.security.dependencies import CurrentUser
from app.training.service import TrainingError, TrainingLabel

router = APIRouter(prefix="/training", tags=["training"])


@router.post("/examples", status_code=status.HTTP_202_ACCEPTED)
async def submit_example(
    request: Request,
    user: CurrentUser,
    image: Annotated[UploadFile, File()],
    label: Annotated[str, Form(description="JSON: {medicines: [...]} as confirmed by the user")],
) -> dict[str, str]:
    """Shares a confirmed prescription for improving the reader (opt-in). The image is redacted and
    held for human review; it is never used before a reviewer approves it."""
    service = request.app.state.training_service
    if service is None or user.is_anonymous:
        raise api_error(
            status.HTTP_503_SERVICE_UNAVAILABLE, "training_disabled", "Not collecting examples"
        )
    try:
        parsed = TrainingLabel.model_validate(json.loads(label))
    except (ValueError, ValidationError) as e:
        raise api_error(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "invalid_label", "Invalid label"
        ) from e
    raw = await image.read(MAX_UPLOAD_BYTES + 1)
    try:
        result = await run_in_threadpool(service.submit, user.id, raw, parsed)
    except ImageError as e:
        raise api_error(status.HTTP_422_UNPROCESSABLE_CONTENT, e.code, e.message) from e
    except TrainingError as e:
        raise api_error(status.HTTP_403_FORBIDDEN, e.code, e.message) from e
    return {"status": "queued_for_review", "example_id": result.example_id}
