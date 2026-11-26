from fastapi import APIRouter, HTTPException, status

from app.schedule.engine import ScheduleError, generate
from app.schedule.models import ScheduleRequest, ScheduleResponse

router = APIRouter(prefix="/schedules", tags=["schedules"])


@router.post("/generate")
def generate_schedule(request: ScheduleRequest) -> ScheduleResponse:
    """Turn confirmed medicines into dose times and grouped reminders.

    Deterministic and rule-based (docs/SCHEDULE_SPEC.md). The app runs the same engine offline.
    """
    try:
        return generate(request)
    except ScheduleError as e:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail={"code": e.code, "message": e.message, "medicine_id": e.medicine_id},
        ) from e
