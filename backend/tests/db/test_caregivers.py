"""Caregiver consent and access rules (Phase 6)."""

import pytest

from .conftest import as_user, fails_with, new_user, psycopg
from .test_rls import _log, _medicine, _prescription


def _invite(db, patient, permission="view"):
    with as_user(db, patient):
        return db.execute("select create_caregiver_invite(%s)", (permission,)).fetchone()[0]


def _accept(db, caregiver, code):
    with as_user(db, caregiver):
        return db.execute("select accept_caregiver_invite(%s)", (code,)).fetchone()[0]


@pytest.fixture
def family(db):
    patient, caregiver, stranger = new_user(db), new_user(db), new_user(db)
    with as_user(db, patient):
        med = _medicine(db, _prescription(db, "confirmed"))
        _log(db, med)
    return patient, caregiver, stranger, med


def test_invite_code_format(db):
    code = _invite(db, new_user(db))
    assert len(code) == 8
    assert not set(code) & set("01OI")


def test_no_access_without_invite(db, family):
    patient, caregiver, _, _ = family
    with as_user(db, caregiver):
        for table in ("medicines", "dose_logs", "prescriptions"):
            assert db.execute(f"select count(*) from {table}").fetchone()[0] == 0
        assert db.execute("select count(*) from profiles").fetchone()[0] == 1  # own only


def test_view_caregiver_can_read_but_not_write(db, family):
    patient, caregiver, stranger, med = family
    _accept(db, caregiver, _invite(db, patient, "view"))
    with as_user(db, caregiver):
        assert db.execute("select count(*) from active_medicines").fetchone()[0] == 1
        assert db.execute("select count(*) from dose_logs").fetchone()[0] == 1
        assert db.execute("select count(*) from profiles").fetchone()[0] == 2
        with fails_with(db, psycopg.errors.InsufficientPrivilege):
            db.execute(
                "insert into prescriptions (user_id, source) values (%s, 'manual')", (patient,)
            )
        assert db.execute("update medicines set name = 'x' returning id").fetchall() == []
    with as_user(db, stranger):
        assert db.execute("select count(*) from medicines").fetchone()[0] == 0


def test_edit_caregiver_can_add_and_confirm_a_prescription(db, family):
    patient, caregiver, _, _ = family
    _accept(db, caregiver, _invite(db, patient, "edit"))
    with as_user(db, caregiver):
        pid = db.execute(
            "insert into prescriptions (user_id, source) values (%s, 'manual') returning id",
            (patient,),
        ).fetchone()[0]
        db.execute(
            "insert into medicines (user_id, prescription_id, name, dose_pattern, duration_days) "
            "values (%s, %s, 'Napa', '1+1+1', 5)",
            (patient, pid),
        )
        db.execute("select confirm_prescription(%s)", (pid,))
    with as_user(db, patient):
        names = sorted(r[0] for r in db.execute("select name from active_medicines"))
    assert names == ["Napa", "Seclo"]


def test_invites_are_single_use_and_expire(db, family):
    patient, caregiver, stranger, _ = family
    code = _invite(db, patient)
    _accept(db, caregiver, code)
    with as_user(db, stranger), fails_with(db, psycopg.errors.RaiseException):
        db.execute("select accept_caregiver_invite(%s)", (code,))
    expired = _invite(db, patient)
    db.execute(
        "update caregiver_invites set expires_at = now() - interval '1 minute' where code = %s",
        (expired,),
    )
    with as_user(db, stranger), fails_with(db, psycopg.errors.RaiseException):
        db.execute("select accept_caregiver_invite(%s)", (expired,))


def test_patient_cannot_accept_own_invite(db, family):
    patient, *_ = family
    code = _invite(db, patient)
    with as_user(db, patient), fails_with(db, psycopg.errors.RaiseException):
        db.execute("select accept_caregiver_invite(%s)", (code,))


def test_codes_are_case_insensitive(db, family):
    patient, caregiver, *_ = family
    code = _invite(db, patient)
    assert _accept(db, caregiver, f"  {code.lower()} ")


def test_either_side_can_revoke(db, family):
    patient, caregiver, _, _ = family
    link = _accept(db, caregiver, _invite(db, patient))
    with as_user(db, patient):
        db.execute("select revoke_caregiver_link(%s)", (link,))
    with as_user(db, caregiver):
        assert db.execute("select count(*) from medicines").fetchone()[0] == 0
    link = _accept(db, caregiver, _invite(db, patient))
    with as_user(db, caregiver):
        db.execute("select revoke_caregiver_link(%s)", (link,))
        assert db.execute("select count(*) from medicines").fetchone()[0] == 0


def test_links_cannot_be_forged_directly(db, family):
    patient, caregiver, _, _ = family
    with as_user(db, caregiver), fails_with(db, psycopg.errors.InsufficientPrivilege):
        db.execute(
            "insert into caregiver_links (patient_id, caregiver_id, permission) "
            "values (%s, %s, 'edit')",
            (patient, caregiver),
        )


def test_invites_are_private_to_the_patient(db, family):
    patient, caregiver, _, _ = family
    _invite(db, patient)
    with as_user(db, caregiver):
        assert db.execute("select count(*) from caregiver_invites").fetchone()[0] == 0


# --- Phase 10: reminder channels ---------------------------------------------------------------


def _channels(db, patient):
    return db.execute(
        "select sms_reminders, call_reminders, feature_phone_mode from profiles where id = %s",
        (patient,),
    ).fetchone()


def test_reminder_channels_are_off_by_default(db, family):
    patient, *_ = family
    assert _channels(db, patient) == (False, False, False)


def test_patient_and_edit_caregiver_may_set_channels(db, family):
    patient, caregiver, stranger, _ = family
    with as_user(db, patient):
        db.execute("select set_reminder_channels(%s, true, false, false)", (patient,))
    assert _channels(db, patient) == (True, False, False)

    _accept(db, caregiver, _invite(db, patient, "edit"))
    with as_user(db, caregiver):
        db.execute("select set_reminder_channels(%s, true, true, true)", (patient,))
    assert _channels(db, patient) == (True, True, True)

    with as_user(db, stranger), fails_with(db, psycopg.errors.InsufficientPrivilege):
        db.execute("select set_reminder_channels(%s, false, false, false)", (patient,))


def test_view_caregiver_may_not_set_channels(db, family):
    patient, caregiver, *_ = family
    _accept(db, caregiver, _invite(db, patient, "view"))
    with as_user(db, caregiver), fails_with(db, psycopg.errors.InsufficientPrivilege):
        db.execute("select set_reminder_channels(%s, true, true, true)", (patient,))
