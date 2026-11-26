"""Exports random schedule cases with the Python engine's answers, for the Dart parity test.

    uv run python -m scripts.export_schedule_parity --out /tmp/parity.json --count 1000

The output uses the same format as spec/schedule/vectors.json "medicine_cases", so the Dart test
(app/test/schedule_parity_test.dart) can check that both engines agree on every case.
"""

import argparse
import json
import random
from datetime import datetime, time, timedelta

from app.prescriptions.schemas import Timing
from app.schedule.engine import (
    ScheduleError,
    _plan,
    occurrences_between,
    schedule_medicine,
    validate_settings,
)
from app.schedule.models import MedicineInput, ScheduleSettings

FMT = "%Y-%m-%dT%H:%M"
AMOUNTS = ["0", "0", "1", "1", "1", "2", "0.5", "½", "১", "1/2", "3", "0.25"]


def _clock(m: int) -> str:
    return f"{m // 60:02d}:{m % 60:02d}"


def random_case(rng: random.Random, n: int) -> dict:
    breakfast = rng.randint(5 * 60, 10 * 60)
    lunch = rng.randint(breakfast + 30, 15 * 60)
    evening = rng.randint(lunch + 30, 19 * 60)
    dinner = rng.randint(evening + 30, 23 * 60 + 59)
    settings = {
        "breakfast": _clock(breakfast),
        "lunch": _clock(lunch),
        "evening": _clock(evening),
        "dinner": _clock(dinner),
        "bedtime": _clock(rng.randint(0, 24 * 60 - 1)),
        "offset_before_meal": rng.choice([-60, -30, -15, 0]),
        "offset_after_meal": rng.choice([0, 15, 30]),
        "offset_empty_stomach": rng.choice([-90, -60, -30]),
    }
    if rng.random() < 0.03:
        settings["lunch"] = settings["breakfast"]  # invalid meal order

    medicine: dict = {
        "id": f"m{n}",
        "timing": rng.choice([t.value for t in Timing]),
        "duration_days": rng.choice([None, None, 1, 2, 3, 5, 7, 10, 14, 30, 90]),
        "start": (
            datetime(2026, 1, 1) + timedelta(minutes=rng.randint(0, 2 * 365 * 24 * 60))
        ).strftime(FMT),
    }
    kind = rng.random()
    if kind < 0.75:
        parts = rng.choice([2, 3, 3, 3, 4]) if rng.random() > 0.05 else rng.choice([1, 5])
        medicine["dose_pattern"] = rng.choice(["+", "-", " + "]).join(
            rng.choice(AMOUNTS) for _ in range(parts)
        )
    elif kind < 0.9:
        medicine["interval_hours"] = rng.choice([4, 6, 8, 12, 24, 1, 2, 3])
        medicine["interval_amount"] = rng.choice(["1", "2", "0.5"])
    else:
        medicine["as_needed"] = True
    if rng.random() < 0.03:
        medicine["duration_days"] = rng.choice([0, 400])  # invalid duration
        medicine.pop("as_needed", None)
    if rng.random() < 0.02:
        medicine["interval_hours"] = 5  # invalid, or conflicting with a pattern
    if rng.random() < 0.15:
        medicine["weekdays"] = sorted(rng.sample(range(1, 8), rng.randint(1, 3)))
    return {"id": f"random_{n}", "settings": settings, "medicine": medicine, "window_days": 4}


def answer(case: dict) -> dict:
    s = dict(case["settings"])
    for key in ("breakfast", "lunch", "evening", "dinner", "bedtime"):
        s[key] = time.fromisoformat(s[key])
    settings = ScheduleSettings(**s)
    med_data = dict(case["medicine"])
    med_data["start"] = datetime.fromisoformat(med_data["start"])
    med = MedicineInput(**med_data)
    try:
        result = schedule_medicine(med, settings)
    except ScheduleError as e:
        return {"error": e.code}
    tz = validate_settings(settings)
    end = med.start + timedelta(days=case["window_days"])
    occ = occurrences_between([_plan(med, settings)], tz, med.start, end)

    def fmt(dt):
        return dt.strftime(FMT) if dt else None

    return {
        "daily_times": [
            f"{t.clock}{'+' + str(t.day_offset) if t.day_offset else ''} {t.amount} {t.slot.value}"
            for t in result.daily_times
        ],
        "doses_per_day": result.doses_per_day,
        "total_doses": result.total_doses,
        "first_dose_at": fmt(result.first_dose_at),
        "last_dose_at": fmt(result.last_dose_at),
        "occurrences": [f"{fmt(o.at)} {o.amount}" for o in occ],
    }


def main(argv=None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    p.add_argument("--count", type=int, default=2000)
    p.add_argument("--seed", type=int, default=20261126)
    args = p.parse_args(argv)
    rng = random.Random(args.seed)
    cases = []
    for n in range(args.count):
        case = random_case(rng, n)
        case["expect"] = answer(case)
        cases.append(case)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump({"medicine_cases": cases}, f, ensure_ascii=False)
    errors = sum("error" in c["expect"] for c in cases)
    print(f"{len(cases)} cases ({errors} invalid inputs) → {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
