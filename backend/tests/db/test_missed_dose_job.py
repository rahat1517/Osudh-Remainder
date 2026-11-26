"""End-to-end missed-dose job against the real schema."""

from datetime import UTC, datetime, timedelta

from app.caregivers.job import run_once
from app.caregivers.notifier import RecordingNotifier
from app.caregivers.repository import CaregiverRepository

from .conftest import as_user, new_user
from .test_caregivers import _accept, _invite
from .test_rls import _log, _medicine, _prescription

DHAKA = timedelta(hours=6)


def at_dhaka(day, hour, minute=0):
    return datetime(2026, 11, day, hour, minute, tzinfo=UTC) - DHAKA


def _setup(db):
    patient, caregiver = new_user(db), new_user(db)
    with as_user(db, patient):
        db.execute("update profiles set display_name = 'আম্মা'")
        med = _medicine(db, _prescription(db, "confirmed"))
        db.execute("update medicines set start_at = %s where id = %s", (at_dhaka(25, 6), med))
    _accept(db, caregiver, _invite(db, patient))
    with as_user(db, caregiver):
        db.execute("insert into push_tokens (token) values ('tok-1'), ('tok-dead')")
    return patient, caregiver, med


def test_job_alerts_caregivers_once(db):
    patient, caregiver, med = _setup(db)
    repo = CaregiverRepository(db)
    notifier = RecordingNotifier(invalid_tokens={"tok-dead"})

    assert run_once(repo, notifier, at_dhaka(26, 21, 31)) == 1
    assert {m.token for m in notifier.sent} == {"tok-1", "tok-dead"}
    msg = notifier.sent[0]
    assert "আম্মা" in msg.title and "২১:০০" in msg.body
    assert msg.data["type"] == "missed_dose"
    # The dead token is removed, the alert recorded
    assert db.execute("select token from push_tokens").fetchall() == [("tok-1",)]
    assert db.execute("select count(*) from missed_dose_alerts").fetchone()[0] == 1

    # Running again sends nothing new
    notifier.sent.clear()
    assert run_once(repo, notifier, at_dhaka(26, 21, 40)) == 0
    assert notifier.sent == []


def test_taken_doses_are_not_alerted(db):
    patient, caregiver, med = _setup(db)
    with as_user(db, patient):
        _log(db, med, "taken", at_dhaka(26, 21).isoformat())
    notifier = RecordingNotifier()
    assert run_once(CaregiverRepository(db), notifier, at_dhaka(26, 21, 31)) == 0


def test_patients_without_caregivers_are_ignored(db):
    lonely = new_user(db)
    with as_user(db, lonely):
        _medicine(db, _prescription(db, "confirmed"))
    repo = CaregiverRepository(db)
    assert [p.patient_id for p in repo.patients_with_caregivers(at_dhaka(25, 0))] == []
