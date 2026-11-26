"""Schedule engine data models (see docs/SCHEDULE_SPEC.md §2 and §4)."""

from datetime import datetime, time
from enum import StrEnum

from pydantic import BaseModel, Field

from app.prescriptions.schemas import Timing

MINUTES_PER_DAY = 24 * 60


class Slot(StrEnum):
    MORNING = "morning"
    NOON = "noon"
    EVENING = "evening"
    NIGHT = "night"
    INTERVAL = "interval"


class ScheduleSettings(BaseModel):
    """Per-user settings. Defaults reflect typical Bangladeshi meal times."""

    breakfast: time = time(8, 0)
    lunch: time = time(13, 30)
    evening: time = time(17, 30)
    dinner: time = time(21, 30)
    bedtime: time = time(22, 30)
    offset_before_meal: int = Field(default=-30, ge=-180, le=0)
    offset_after_meal: int = Field(default=15, ge=0, le=180)
    offset_empty_stomach: int = Field(default=-60, ge=-240, le=0)
    group_window_minutes: int = Field(default=10, ge=0, le=60)
    timezone: str = "Asia/Dhaka"


class MedicineInput(BaseModel):
    id: str = Field(min_length=1, max_length=100)
    dose_pattern: str | None = Field(default=None, max_length=40, examples=["1+0+1"])
    interval_hours: int | None = None
    interval_amount: str = Field(default="1", max_length=10)
    timing: Timing = Timing.NOT_SPECIFIED
    duration_days: int | None = Field(description="null = continue indefinitely")
    weekdays: list[int] | None = Field(default=None, description="ISO weekdays, 1 = Monday")
    as_needed: bool = False
    start: datetime | None = Field(
        default=None, description="Wall-clock start; defaults to the request's start"
    )


class DoseTime(BaseModel):
    slot: Slot
    minutes: int = Field(description="Minutes from the start of the schedule day; may exceed 1440")
    amount: str

    @property
    def day_offset(self) -> int:
        return self.minutes // MINUTES_PER_DAY

    @property
    def clock(self) -> str:
        m = self.minutes % MINUTES_PER_DAY
        return f"{m // 60:02d}:{m % 60:02d}"


class MedicineSchedule(BaseModel):
    medicine_id: str
    doses_per_day: int
    daily_times: list[DoseTime]
    total_doses: int | None
    first_dose_at: datetime | None
    last_dose_at: datetime | None


class Occurrence(BaseModel):
    at: datetime
    medicine_id: str
    amount: str
    slot: Slot


class Reminder(BaseModel):
    at: datetime
    items: list[Occurrence]


class ScheduleRequest(BaseModel):
    settings: ScheduleSettings = Field(default_factory=ScheduleSettings)
    start: datetime = Field(description="Start of the reminder window (wall-clock or with offset)")
    days: int = Field(default=7, ge=1, le=31, description="Length of the reminder window")
    medicines: list[MedicineInput] = Field(min_length=1, max_length=50)


class ScheduleResponse(BaseModel):
    timezone: str
    medicines: list[MedicineSchedule]
    reminders: list[Reminder]
