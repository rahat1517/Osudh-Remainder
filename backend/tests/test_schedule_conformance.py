"""Runs the shared conformance suite (spec/schedule/vectors.json) against the Python engine.

The Dart implementation runs the same file in app/test/schedule_conformance_test.dart.
"""

import json
from datetime import datetime, time, timedelta
from pathlib import Path

import pytest

from app.schedule.engine import (
    ScheduleError,
    generate,
    occurrences_between,
    schedule_medicine,
    validate_settings,
)
from app.schedule.engine import _plan as plan_medicine
from app.schedule.models import MedicineInput, ScheduleRequest, ScheduleSettings

VECTORS = json.loads(
    (Path(__file__).parents[2] / "spec" / "schedule" / "vectors.json").read_text(encoding="utf-8")
)
FMT = "%Y-%m-%dT%H:%M"


def _settings(overrides: dict | None) -> ScheduleSettings:
    data = dict(overrides or {})
    for key in ("breakfast", "lunch", "evening", "dinner", "bedtime"):
        if key in data:
            data[key] = time.fromisoformat(data[key])
    return ScheduleSettings(**data)


def _medicine(data: dict) -> MedicineInput:
    data = {"id": "m", **data}
    if data.get("start"):
        data["start"] = datetime.fromisoformat(data["start"])
    return MedicineInput(**data)


def _fmt(dt: datetime | None) -> str | None:
    return dt.strftime(FMT) if dt else None


def _fmt_time(t) -> str:
    suffix = f"+{t.day_offset}" if t.day_offset else ""
    return f"{t.clock}{suffix} {t.amount} {t.slot.value}"


@pytest.mark.parametrize("case", VECTORS["medicine_cases"], ids=lambda c: c["id"])
def test_medicine_case(case):
    settings = _settings(case.get("settings"))
    med = _medicine(case["medicine"])
    expect = case["expect"]

    if "error" in expect:
        with pytest.raises(ScheduleError) as exc:
            schedule_medicine(med, settings)
        assert exc.value.code == expect["error"]
        return

    result = schedule_medicine(med, settings)
    if "daily_times" in expect:
        assert [_fmt_time(t) for t in result.daily_times] == expect["daily_times"]
    if "doses_per_day" in expect:
        assert result.doses_per_day == expect["doses_per_day"]
    if "total_doses" in expect:
        assert result.total_doses == expect["total_doses"]
    if "first_dose_at" in expect:
        assert _fmt(result.first_dose_at) == expect["first_dose_at"]
    if "last_dose_at" in expect:
        assert _fmt(result.last_dose_at) == expect["last_dose_at"]
    if "occurrences" in expect:
        tz = validate_settings(settings)
        start = med.start
        end = start + timedelta(days=case.get("window_days", 7))
        occ = occurrences_between([plan_medicine(med, settings)], tz, start, end)
        assert [f"{_fmt(o.at)} {o.amount}" for o in occ] == expect["occurrences"]


@pytest.mark.parametrize("case", VECTORS["grouping_cases"], ids=lambda c: c["id"])
def test_grouping_case(case):
    request = ScheduleRequest(
        settings=_settings(case.get("settings")),
        start=datetime.fromisoformat(case["start"]),
        days=case["window_days"],
        medicines=[_medicine(m) for m in case["medicines"]],
    )
    reminders = generate(request).reminders
    got = [f"{_fmt(r.at)} {','.join(i.medicine_id for i in r.items)}" for r in reminders]
    assert got == case["expect_reminders"]
