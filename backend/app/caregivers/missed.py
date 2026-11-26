"""Missed-dose detection (pure).

A dose is missed when it was scheduled at least `grace` ago, within the lookback window, and the
patient has neither taken nor skipped it, and no alert was sent for it yet. Uses the same schedule
engine as the app, so server and phone agree on when doses are due.
"""

from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta

from app.schedule.engine import occurrences_for
from app.schedule.models import MedicineInput, ScheduleSettings

DEFAULT_GRACE = timedelta(minutes=30)
DEFAULT_LOOKBACK = timedelta(hours=6)


@dataclass(frozen=True)
class MissedDose:
    medicine_id: str
    medicine_label: str
    scheduled_at: datetime  # aware
    amount: str


@dataclass
class PatientSnapshot:
    patient_id: str
    settings: ScheduleSettings
    medicines: list[MedicineInput]
    labels: dict[str, str]
    # (medicine_id, scheduled_at in UTC) already taken/skipped, or already alerted
    handled: set[tuple[str, datetime]] = field(default_factory=set)


def _key(medicine_id: str, at: datetime) -> tuple[str, datetime]:
    return medicine_id, at.astimezone(UTC).replace(second=0, microsecond=0)


def find_missed(
    patient: PatientSnapshot,
    now: datetime,
    grace: timedelta = DEFAULT_GRACE,
    lookback: timedelta = DEFAULT_LOOKBACK,
) -> list[MissedDose]:
    if not patient.medicines:
        return []
    handled = {_key(m, at) for m, at in patient.handled}
    occurrences = occurrences_for(patient.medicines, patient.settings, now - lookback, now - grace)
    return [
        MissedDose(o.medicine_id, patient.labels.get(o.medicine_id, ""), o.at, o.amount)
        for o in occurrences
        if _key(o.medicine_id, o.at) not in handled
    ]
