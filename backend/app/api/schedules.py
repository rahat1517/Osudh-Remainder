from fastapi import APIRouter, status

from app.api.errors import api_error
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
        raise api_error(
            status.HTTP_422_UNPROCESSABLE_CONTENT, e.code, e.message, medicine_id=e.medicine_id
        ) from e
