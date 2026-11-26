"""Schedule engine (docs/SCHEDULE_SPEC.md).

Pure functions, no I/O, no AI. Every rule here is mirrored in the Dart implementation
(app/lib/schedule/) and both are checked against spec/schedule/vectors.json.
"""

import heapq
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from fractions import Fraction
from itertools import count
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.prescriptions.dose import normalize_dose_pattern
from app.prescriptions.schemas import Timing
from app.schedule.models import (
    MINUTES_PER_DAY,
    DoseTime,
    MedicineInput,
    MedicineSchedule,
    Occurrence,
    Reminder,
    ScheduleRequest,
    ScheduleResponse,
    ScheduleSettings,
    Slot,
)

MAX_DURATION_DAYS = 365
VALID_INTERVALS = {1, 2, 3, 4, 6, 8, 12, 24}

_SLOTS_BY_PARTS = {
    2: (Slot.MORNING, Slot.NIGHT),
    3: (Slot.MORNING, Slot.NOON, Slot.NIGHT),
    4: (Slot.MORNING, Slot.NOON, Slot.EVENING, Slot.NIGHT),
}


class ScheduleError(ValueError):
    """Invalid input. `code` is one of the error codes in spec §6."""

    def __init__(self, code: str, message: str, medicine_id: str | None = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.medicine_id = medicine_id


@dataclass(frozen=True)
class _Plan:
    medicine: MedicineInput
    times: tuple[DoseTime, ...]
    total: int | None  # dose-count limit for daily courses
    weekly_end: date | None  # exclusive end date for weekly courses


# ---------------------------------------------------------------------------
# Validation and daily times (spec §2, §3.1–3.5)
# ---------------------------------------------------------------------------
def _minutes(t: time) -> int:
    return t.hour * 60 + t.minute


def validate_settings(settings: ScheduleSettings) -> ZoneInfo:
    meals = [settings.breakfast, settings.lunch, settings.evening, settings.dinner]
    if any(a >= b for a, b in zip(meals, meals[1:], strict=False)):
        raise ScheduleError(
            "invalid_meal_times",
            "Meal times must be in order: breakfast < lunch < evening < dinner",
        )
    try:
        return ZoneInfo(settings.timezone)
    except (ZoneInfoNotFoundError, ValueError) as e:
        raise ScheduleError("invalid_timezone", f"Unknown time zone {settings.timezone!r}") from e


def _fmt_amount(value: Fraction) -> str:
    return str(int(value)) if value.denominator == 1 else f"{float(value):g}"


def _meal_minutes(slot: Slot, s: ScheduleSettings) -> int:
    return _minutes(
        {
            Slot.MORNING: s.breakfast,
            Slot.NOON: s.lunch,
            Slot.EVENING: s.evening,
            Slot.NIGHT: s.dinner,
        }[slot]
    )


def _bedtime_minutes(s: ScheduleSettings) -> int:
    m = _minutes(s.bedtime)
    return m + MINUTES_PER_DAY if m < _minutes(s.breakfast) else m


def _offset(timing: Timing, s: ScheduleSettings) -> int:
    return {
        Timing.BEFORE_MEAL: s.offset_before_meal,
        Timing.AFTER_MEAL: s.offset_after_meal,
        Timing.EMPTY_STOMACH: s.offset_empty_stomach,
    }.get(timing, 0)


def daily_times(med: MedicineInput, s: ScheduleSettings) -> tuple[DoseTime, ...]:
    """Dose times within one schedule day, ordered by time (spec §3.1–3.5)."""
    if med.as_needed:
        return ()
    if med.interval_hours is not None:
        start = _minutes(s.breakfast)
        step = med.interval_hours * 60
        return tuple(
            DoseTime(slot=Slot.INTERVAL, minutes=start + i * step, amount=med.interval_amount)
            for i in range(24 // med.interval_hours)
        )

    pattern = normalize_dose_pattern(med.dose_pattern)
    assert pattern is not None  # validated by _plan
    amounts = [Fraction(a) for a in pattern.split("+")]
    times = []
    for slot, amount in zip(_SLOTS_BY_PARTS[len(amounts)], amounts, strict=True):
        if amount == 0:
            continue
        if med.timing == Timing.BEDTIME and slot == Slot.NIGHT:
            minutes = _bedtime_minutes(s)
        else:
            minutes = _meal_minutes(slot, s) + _offset(med.timing, s)
        times.append(DoseTime(slot=slot, minutes=minutes, amount=_fmt_amount(amount)))
    return tuple(sorted(times, key=lambda t: t.minutes))


def _plan(med: MedicineInput, s: ScheduleSettings) -> _Plan:
    def fail(code: str, message: str):
        raise ScheduleError(code, message, med.id)

    if med.dose_pattern is not None and med.interval_hours is not None:
        fail("conflicting_dose", "Give either dose_pattern or interval_hours, not both")
    if not med.as_needed:
        if med.dose_pattern is None and med.interval_hours is None:
            fail("missing_dose", "A dose_pattern or interval_hours is required")
        if med.dose_pattern is not None and normalize_dose_pattern(med.dose_pattern) is None:
            fail("invalid_dose_pattern", f"Cannot use dose pattern {med.dose_pattern!r}")
        if med.interval_hours is not None and med.interval_hours not in VALID_INTERVALS:
            fail("invalid_interval", "interval_hours must divide 24")
    if med.duration_days is not None and not 1 <= med.duration_days <= MAX_DURATION_DAYS:
        fail("invalid_duration", f"duration_days must be between 1 and {MAX_DURATION_DAYS}")
    if med.weekdays is not None and (
        not med.weekdays or any(not 1 <= d <= 7 for d in med.weekdays)
    ):
        fail("invalid_weekdays", "weekdays must be a non-empty list of ISO weekdays 1-7")

    times = daily_times(med, s)
    total = weekly_end = None
    if med.duration_days is not None and times:
        if med.weekdays:
            assert med.start is not None
            weekly_end = med.start.date() + timedelta(days=med.duration_days)
        else:
            total = med.duration_days * len(times)
    return _Plan(med, times, total, weekly_end)


# ---------------------------------------------------------------------------
# Occurrences (spec §3.6, §3.7)
# ---------------------------------------------------------------------------
def _local(dt: datetime, tz: ZoneInfo) -> datetime:
    return dt.replace(tzinfo=tz) if dt.tzinfo is None else dt.astimezone(tz)


def _iter_occurrences(plan: _Plan, tz: ZoneInfo) -> Iterator[Occurrence]:
    """Occurrences from the medicine's start onward, in chronological order.

    Infinite for indefinite courses; callers bound it. A small heap keeps the output ordered even
    when an after-midnight dose (e.g. bedtime 00:30+1) lands after the next day's earliest dose.
    """
    med, times = plan.medicine, plan.times
    if not times:
        return
    assert med.start is not None
    start = _local(med.start, tz)
    earliest = times[0].minutes
    weekdays = set(med.weekdays or ())
    weekly_end_at = (
        datetime.combine(plan.weekly_end, time(), tz) if plan.weekly_end is not None else None
    )

    pending: list[tuple[datetime, int, Occurrence]] = []
    seq = count()
    emitted = 0
    day = start.date() - timedelta(days=1)  # a dose of yesterday's schedule day may fall today
    last_day = start.date() + timedelta(days=MAX_DURATION_DAYS + 2)

    while True:
        day_start = datetime.combine(day, time(), tz)
        threshold = day_start + timedelta(minutes=earliest)
        while pending and pending[0][0] < threshold:
            yield heapq.heappop(pending)[2]
            emitted += 1
            if plan.total is not None and emitted == plan.total:
                return
        done = (plan.weekly_end is not None and day >= plan.weekly_end) or (
            plan.total is not None and day > last_day
        )
        if done:
            while pending:
                yield heapq.heappop(pending)[2]
            return

        if not weekdays or day.isoweekday() in weekdays:
            for t in times:
                at = day_start + timedelta(minutes=t.minutes)
                if at < start or (weekly_end_at is not None and at >= weekly_end_at):
                    continue
                occ = Occurrence(at=at, medicine_id=med.id, amount=t.amount, slot=t.slot)
                heapq.heappush(pending, (at, next(seq), occ))
        day += timedelta(days=1)


def _summary(plan: _Plan, tz: ZoneInfo) -> MedicineSchedule:
    first = last = None
    total = plan.total
    finite = plan.total is not None or plan.weekly_end is not None
    occurrences = _iter_occurrences(plan, tz)
    first_occ = next(occurrences, None)
    if first_occ is not None:
        first = first_occ.at
        if finite:
            n, last_occ = 1, first_occ
            for last_occ in occurrences:  # noqa: B007 (we want the final value)
                n += 1
            last = last_occ.at
            total = n
    elif finite:
        total = 0
    return MedicineSchedule(
        medicine_id=plan.medicine.id,
        doses_per_day=len(plan.times),
        daily_times=list(plan.times),
        total_doses=total,
        first_dose_at=first,
        last_dose_at=last,
    )


def occurrences_between(
    plans: Iterable[_Plan], tz: ZoneInfo, window_start: datetime, window_end: datetime
) -> list[Occurrence]:
    window_start, window_end = _local(window_start, tz), _local(window_end, tz)
    result = []
    for plan in plans:
        for occ in _iter_occurrences(plan, tz):
            if occ.at >= window_end:
                break
            if occ.at >= window_start:
                result.append(occ)
    result.sort(key=lambda o: (o.at, o.medicine_id))
    return result


# ---------------------------------------------------------------------------
# Reminder grouping (spec §5)
# ---------------------------------------------------------------------------
def group_reminders(occurrences: Iterable[Occurrence], window_minutes: int) -> list[Reminder]:
    window = timedelta(minutes=window_minutes)
    reminders: list[Reminder] = []
    for occ in sorted(occurrences, key=lambda o: (o.at, o.medicine_id)):
        if reminders and occ.at - reminders[-1].at <= window:
            reminders[-1].items.append(occ)
        else:
            reminders.append(Reminder(at=occ.at, items=[occ]))
    return reminders


# ---------------------------------------------------------------------------
# Public entry points
# ---------------------------------------------------------------------------
def schedule_medicine(med: MedicineInput, settings: ScheduleSettings) -> MedicineSchedule:
    tz = validate_settings(settings)
    return _summary(_plan(med, settings), tz)


def generate(request: ScheduleRequest) -> ScheduleResponse:
    settings = request.settings
    tz = validate_settings(settings)
    plans = []
    for med in request.medicines:
        if med.start is None:
            med = med.model_copy(update={"start": request.start})
        plans.append(_plan(med, settings))

    window_start = _local(request.start, tz)
    window_end = window_start + timedelta(days=request.days)
    occurrences = occurrences_between(plans, tz, window_start, window_end)
    return ScheduleResponse(
        timezone=settings.timezone,
        medicines=[_summary(p, tz) for p in plans],
        reminders=group_reminders(occurrences, settings.group_window_minutes),
    )
