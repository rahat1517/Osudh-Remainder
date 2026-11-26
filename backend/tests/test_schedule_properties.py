"""Property-based tests: invariants that must hold for every valid input (spec §3–§5)."""

from datetime import datetime, time, timedelta

from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

from app.prescriptions.schemas import Timing
from app.schedule.engine import (
    _plan,
    group_reminders,
    occurrences_between,
    schedule_medicine,
    validate_settings,
)
from app.schedule.models import MedicineInput, ScheduleSettings

AMOUNTS = ["0", "0.5", "1", "2", "½", "১"]


@st.composite
def dose_patterns(draw):
    parts = draw(st.integers(min_value=2, max_value=4))
    amounts = draw(st.lists(st.sampled_from(AMOUNTS), min_size=parts, max_size=parts))
    if all(a == "0" for a in amounts):
        amounts[0] = "1"
    return "+".join(amounts)


@st.composite
def meal_settings(draw):
    # Strictly increasing meal times with realistic ranges
    breakfast = draw(st.integers(min_value=5 * 60, max_value=10 * 60))
    lunch = draw(st.integers(min_value=breakfast + 60, max_value=15 * 60))
    evening = draw(st.integers(min_value=lunch + 60, max_value=19 * 60))
    dinner = draw(st.integers(min_value=evening + 60, max_value=23 * 60 + 59))
    bedtime = draw(st.integers(min_value=0, max_value=24 * 60 - 1))

    def t(m):
        return time(m // 60, m % 60)

    return ScheduleSettings(
        breakfast=t(breakfast),
        lunch=t(lunch),
        evening=t(evening),
        dinner=t(dinner),
        bedtime=t(bedtime),
        group_window_minutes=draw(st.integers(min_value=0, max_value=60)),
    )


starts = st.datetimes(min_value=datetime(2026, 1, 1), max_value=datetime(2027, 12, 31)).map(
    lambda d: d.replace(second=0, microsecond=0)
)
timings = st.sampled_from(list(Timing))


DEFAULT_DURATION = st.integers(min_value=1, max_value=60)


@st.composite
def daily_medicines(draw, duration=DEFAULT_DURATION):
    use_interval = draw(st.booleans())
    return MedicineInput(
        id=draw(st.sampled_from(["a", "b", "c", "d"])),
        dose_pattern=None if use_interval else draw(dose_patterns()),
        interval_hours=draw(st.sampled_from([4, 6, 8, 12, 24])) if use_interval else None,
        timing=draw(timings),
        duration_days=draw(duration),
        start=draw(starts),
    )


fast = settings(max_examples=150, deadline=None, suppress_health_check=[HealthCheck.too_slow])


@fast
@given(med=daily_medicines(), s=meal_settings())
def test_course_has_exact_dose_count(med, s):
    result = schedule_medicine(med, s)
    assert result.total_doses == med.duration_days * result.doses_per_day


@fast
@given(med=daily_medicines(), s=meal_settings())
def test_occurrences_are_ordered_and_match_summary(med, s):
    tz = validate_settings(s)
    result = schedule_medicine(med, s)
    window_end = med.start + timedelta(days=med.duration_days + 3)
    occ = occurrences_between([_plan(med, s)], tz, med.start, window_end)

    assert len(occ) == result.total_doses
    assert all(a.at <= b.at for a, b in zip(occ, occ[1:], strict=False))
    assert occ[0].at == result.first_dose_at
    assert occ[-1].at == result.last_dose_at
    assert occ[0].at >= med.start.replace(tzinfo=tz)
    clocks = {t.clock for t in result.daily_times}
    assert all(o.at.strftime("%H:%M") in clocks for o in occ)


@fast
@given(med=daily_medicines(duration=st.none()), s=meal_settings(), days=st.integers(1, 30))
def test_indefinite_course_never_ends(med, s, days):
    tz = validate_settings(s)
    result = schedule_medicine(med, s)
    assert result.total_doses is None and result.last_dose_at is None
    occ = occurrences_between([_plan(med, s)], tz, med.start, med.start + timedelta(days=days))
    per_day = result.doses_per_day
    assert (days - 1) * per_day <= len(occ) <= (days + 1) * per_day


@fast
@given(
    med=daily_medicines(duration=st.integers(1, 60)),
    weekdays=st.lists(st.integers(1, 7), min_size=1, max_size=7, unique=True),
    s=meal_settings(),
)
def test_weekly_medicines_only_on_chosen_days(med, weekdays, s):
    med = med.model_copy(update={"weekdays": weekdays})
    tz = validate_settings(s)
    occ = occurrences_between([_plan(med, s)], tz, med.start, med.start + timedelta(days=70))
    end = med.start.date() + timedelta(days=med.duration_days)
    minutes = {t.minutes for t in schedule_medicine(med, s).daily_times}
    for o in occ:
        # A dose belongs to the schedule day it was computed from, which may be the previous
        # calendar day for after-midnight times (spec §3.4).
        local = o.at.replace(tzinfo=None)
        owners = [
            d
            for d in (local.date(), local.date() - timedelta(days=1))
            if int((local - datetime.combine(d, time())).total_seconds() // 60) in minutes
        ]
        assert any(d.isoweekday() in weekdays for d in owners), (o.at, owners)
        assert all(d < end for d in owners if d.isoweekday() in weekdays)
    assert schedule_medicine(med, s).total_doses == len(occ)


@fast
@given(meds=st.lists(daily_medicines(), min_size=1, max_size=4), s=meal_settings())
def test_grouping_never_delays_and_never_loses_a_dose(meds, s):
    tz = validate_settings(s)
    start = min(m.start for m in meds)
    plans = [_plan(m, s) for m in meds]
    occ = occurrences_between(plans, tz, start, start + timedelta(days=5))
    reminders = group_reminders(occ, s.group_window_minutes)

    assert sum(len(r.items) for r in reminders) == len(occ)
    window = timedelta(minutes=s.group_window_minutes)
    for r in reminders:
        for item in r.items:
            assert r.at <= item.at <= r.at + window  # only ever earlier, by at most the window
    assert all(a.at < b.at for a, b in zip(reminders, reminders[1:], strict=False))


@fast
@given(med=daily_medicines(), shift=st.integers(min_value=-60, max_value=60))
def test_shifting_all_meals_shifts_doses_equally(med, shift):
    if med.timing == Timing.BEDTIME:
        med = med.model_copy(update={"timing": Timing.NOT_SPECIFIED})
    base = ScheduleSettings()

    def moved(t: time) -> time:
        dt = datetime.combine(datetime(2026, 1, 1), t) + timedelta(minutes=shift)
        return dt.time()

    shifted = base.model_copy(
        update={k: moved(getattr(base, k)) for k in ("breakfast", "lunch", "evening", "dinner")}
    )
    a = schedule_medicine(med, base).daily_times
    b = schedule_medicine(med, shifted).daily_times
    assert [t.minutes + shift for t in a] == [t.minutes for t in b]
