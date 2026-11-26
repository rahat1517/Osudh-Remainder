from typing import Annotated

from fastapi import APIRouter, Depends, File, Request, UploadFile, status
from fastapi.concurrency import run_in_threadpool

from app.api.errors import api_error
from app.prescriptions.errors import ImageError, NotAPrescriptionError, PrescriptionError
from app.prescriptions.images import MAX_UPLOAD_BYTES
from app.prescriptions.schemas import PrescriptionResult
from app.prescriptions.service import PrescriptionService
from app.security.dependencies import AiUser

router = APIRouter(prefix="/prescriptions", tags=["prescriptions"])


def get_service(request: Request) -> PrescriptionService:
    service = request.app.state.prescription_service
    if service is None:
        raise api_error(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "ai_not_configured",
            "Prescription reading is not configured on this server",
        )
    return service


ServiceDep = Annotated[PrescriptionService, Depends(get_service)]


@router.post(
    "/extract",
    responses={
        401: {"description": "auth_required or auth_invalid"},
        422: {"description": "image_* or not_a_prescription"},
        429: {"description": "rate_limited (see Retry-After)"},
        502: {"description": "ai_refused, ai_failed or prescription_too_long"},
        503: {"description": "ai_not_configured, ai_rate_limited or ai_unavailable (retry)"},
    },
)
async def extract_prescription(
    user: AiUser,
    service: ServiceDep,
    image: Annotated[UploadFile, File(description="Prescription photo (JPEG, PNG or WebP)")],
) -> PrescriptionResult:
    """Read the medicines from a prescription photo, with a confidence for every field.

    The result must always be shown to the user for confirmation (`requires_confirmation`).
    The image is not stored.
    """
    raw = await image.read(MAX_UPLOAD_BYTES + 1)
    try:
        # The AI call takes seconds; keep the event loop free for other requests
        return await run_in_threadpool(service.extract, raw)
    except (ImageError, NotAPrescriptionError) as e:
        raise api_error(status.HTTP_422_UNPROCESSABLE_CONTENT, e.code, e.message) from e
    except PrescriptionError as e:
        code = status.HTTP_503_SERVICE_UNAVAILABLE if e.retryable else status.HTTP_502_BAD_GATEWAY
        raise api_error(code, e.code, e.message) from e
