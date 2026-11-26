from datetime import UTC, datetime, timedelta

from app.caregivers.messages import missed_dose_text
from app.caregivers.missed import PatientSnapshot, find_missed
from app.caregivers.notifier import PushMessage, RecordingNotifier
from app.prescriptions.schemas import Timing
from app.schedule.models import MedicineInput, ScheduleSettings

DHAKA = timedelta(hours=6)


def at_dhaka(day: int, hour: int, minute: int = 0) -> datetime:
    return datetime(2026, 11, day, hour, minute, tzinfo=UTC) - DHAKA


def patient(handled=()):
    return PatientSnapshot(
        patient_id="p1",
        settings=ScheduleSettings(),
        medicines=[
            MedicineInput(
                id="seclo",
                dose_pattern="1+0+1",
                timing=Timing.BEFORE_MEAL,
                duration_days=30,
                start=at_dhaka(25, 6),
            )
        ],
        labels={"seclo": "Seclo 20 mg"},
        handled=set(handled),
    )


def test_dose_is_missed_after_the_grace_period():
    # Seclo before dinner is due 21:00 Dhaka; at 21:20 it is not yet missed, at 21:31 it is
    assert find_missed(patient(), at_dhaka(26, 21, 20)) == []
    missed = find_missed(patient(), at_dhaka(26, 21, 31))
    assert [(m.medicine_id, m.scheduled_at) for m in missed] == [("seclo", at_dhaka(26, 21))]
    assert missed[0].medicine_label == "Seclo 20 mg"


def test_taken_or_alerted_doses_are_not_missed():
    handled = {("seclo", at_dhaka(26, 21))}
    assert find_missed(patient(handled), at_dhaka(26, 21, 31)) == []


def test_lookback_limits_old_doses():
    # At 08:30 the next morning only this morning's 07:30 dose counts, not last night's
    missed = find_missed(patient(), at_dhaka(27, 8, 30), lookback=timedelta(hours=6))
    assert [m.scheduled_at for m in missed] == [at_dhaka(27, 7, 30)]


def test_handled_keys_ignore_seconds():
    handled = {("seclo", at_dhaka(26, 21) + timedelta(seconds=30))}
    assert find_missed(patient(handled), at_dhaka(26, 21, 31)) == []


def test_bangla_and_english_texts():
    title, body = missed_dose_text("bn", "আম্মা", ["Seclo 20 mg"], "21:00")
    assert "আম্মা" in title and "২১:০০" in body and "Seclo 20 mg" in body
    title, body = missed_dose_text("en", "Mother", ["Seclo 20 mg", "Napa"], "21:00")
    assert title == "Mother has not taken a medicine"
    assert body == "Seclo 20 mg, Napa due at 21:00 has not been taken yet."


def test_recording_notifier_reports_invalid_tokens():
    n = RecordingNotifier(invalid_tokens={"dead"})
    assert n.send([PushMessage("ok", "t", "b"), PushMessage("dead", "t", "b")]) == ["dead"]
    assert len(n.sent) == 2
