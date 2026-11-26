from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from fastapi.concurrency import run_in_threadpool

from app.prescriptions.images import MAX_UPLOAD_BYTES, ImageError
from app.prescriptions.reader import ReaderError
from app.prescriptions.schemas import PrescriptionResult
from app.prescriptions.service import NotAPrescriptionError, PrescriptionService

router = APIRouter(prefix="/prescriptions", tags=["prescriptions"])


def get_service(request: Request) -> PrescriptionService:
    service = request.app.state.prescription_service
    if service is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="প্রেসক্রিপশন পড়ার AI সেবা এখন চালু নেই। ওষুধ নিজে যোগ করুন।",
        )
    return service


ServiceDep = Annotated[PrescriptionService, Depends(get_service)]


@router.post("/extract")
async def extract_prescription(
    service: ServiceDep,
    image: Annotated[UploadFile, File(description="প্রেসক্রিপশনের ছবি (JPEG/PNG/WebP)")],
) -> PrescriptionResult:
    """প্রেসক্রিপশনের ছবি থেকে ওষুধের তালিকা, প্রতিটা ঘরের confidence-সহ।

    ফলাফল সবসময় ব্যবহারকারীকে দেখিয়ে confirm করাতে হবে (`requires_confirmation`)।
    ছবি সংরক্ষণ করা হয় না।
    """
    raw = await image.read(MAX_UPLOAD_BYTES + 1)
    try:
        # AI-এর উত্তর আসতে কয়েক সেকেন্ড লাগে; server-এর অন্য অনুরোধ যেন আটকে না থাকে
        return await run_in_threadpool(service.extract, raw)
    except ImageError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(e)) from e
    except NotAPrescriptionError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail=e.user_message) from e
    except ReaderError as e:
        code = status.HTTP_503_SERVICE_UNAVAILABLE if e.retryable else status.HTTP_502_BAD_GATEWAY
        raise HTTPException(code, detail=e.user_message) from e
