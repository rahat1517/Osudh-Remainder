"""Row-level security and integrity rules of the Supabase schema."""

import pytest

from .conftest import as_user, fails_with, new_user, psycopg


def _prescription(db, status="draft"):
    pid = db.execute("insert into prescriptions (source) values ('scan') returning id").fetchone()[
        0
    ]
    if status == "confirmed":
        db.execute("select confirm_prescription(%s)", (pid,))
    return pid


def _medicine(db, prescription_id, **overrides):
    values = {
        "name": "Seclo",
        "dose_pattern": "1+0+1",
        "timing": "before_meal",
        "duration_days": 30,
    }
    values.update(overrides)
    cols = ", ".join(["prescription_id", *values])
    marks = ", ".join(["%s"] * (len(values) + 1))
    return db.execute(
        f"insert into medicines ({cols}) values ({marks}) returning id",
        (prescription_id, *values.values()),
    ).fetchone()[0]


def test_profile_is_created_on_sign_up(db):
    user = new_user(db)
    with as_user(db, user):
        row = db.execute("select locale, timezone, breakfast::text from profiles").fetchone()
    assert row == ("bn", "Asia/Dhaka", "08:00:00")


def test_users_only_see_their_own_rows(db):
    alice, bob = new_user(db), new_user(db)
    with as_user(db, alice):
        pid = _prescription(db, "confirmed")
        _medicine(db, pid)
    with as_user(db, bob):
        assert db.execute("select count(*) from prescriptions").fetchone()[0] == 0
        assert db.execute("select count(*) from medicines").fetchone()[0] == 0
        assert db.execute("select count(*) from active_medicines").fetchone()[0] == 0
        assert db.execute("select count(*) from profiles").fetchone()[0] == 1  # only Bob's
        updated = db.execute("update medicines set name = 'x' returning id").fetchall()
        assert updated == []


def test_cannot_attach_medicine_to_someone_elses_prescription(db):
    alice, bob = new_user(db), new_user(db)
    with as_user(db, alice):
        alice_pid = _prescription(db)
    with as_user(db, bob), fails_with(db, psycopg.errors.InsufficientPrivilege):
        _medicine(db, alice_pid)


def test_cannot_insert_rows_for_another_user(db):
    alice, bob = new_user(db), new_user(db)
    with as_user(db, bob), fails_with(db, psycopg.errors.InsufficientPrivilege):
        db.execute("insert into prescriptions (user_id, source) values (%s, 'scan')", (alice,))


def test_only_confirmed_and_running_medicines_are_active(db):
    user = new_user(db)
    with as_user(db, user):
        draft = _prescription(db)
        _medicine(db, draft, name="Draft")
        confirmed = _prescription(db, "confirmed")
        _medicine(db, confirmed, name="Active")
        stopped = _medicine(db, confirmed, name="Stopped")
        db.execute("update medicines set stopped_at = now() where id = %s", (stopped,))
        names = [r[0] for r in db.execute("select name from active_medicines")]
    assert names == ["Active"]


def test_confirm_prescription_only_affects_own_drafts(db):
    alice, bob = new_user(db), new_user(db)
    with as_user(db, alice):
        pid = _prescription(db)
    with as_user(db, bob):
        db.execute("select confirm_prescription(%s)", (pid,))
    with as_user(db, alice):
        assert db.execute("select status from prescriptions").fetchone()[0] == "draft"
        db.execute("select confirm_prescription(%s)", (pid,))
        status, confirmed_at = db.execute(
            "select status, confirmed_at from prescriptions"
        ).fetchone()
    assert status == "confirmed" and confirmed_at is not None


def test_anonymous_clients_see_drugs_but_no_personal_data(db):
    user = new_user(db)
    with as_user(db, user):
        _prescription(db)
    with as_user(db, None):
        assert db.execute("select count(*) from drugs").fetchone()[0] > 0
        with fails_with(db, psycopg.errors.InsufficientPrivilege):
            db.execute("select count(*) from prescriptions")


@pytest.mark.parametrize(
    "overrides",
    [
        {"timing": "sometimes"},
        {"duration_days": 0},
        {"dose_pattern": None},  # no dose at all
        {"interval_hours": 8},  # both pattern and interval
        {"weekdays": [0]},
    ],
)
def test_medicine_constraints(db, overrides):
    user = new_user(db)
    with as_user(db, user):
        pid = _prescription(db)
        with fails_with(db, psycopg.errors.CheckViolation):
            _medicine(db, pid, **overrides)


def test_meal_times_must_be_ordered(db):
    user = new_user(db)
    with as_user(db, user), fails_with(db, psycopg.errors.CheckViolation):
        db.execute("update profiles set lunch = '07:00'")


def test_deleting_the_user_removes_all_their_data(db):
    user = new_user(db)
    with as_user(db, user):
        _medicine(db, _prescription(db, "confirmed"))
    db.execute("delete from auth.users where id = %s", (user,))
    for table in ("profiles", "prescriptions", "medicines"):
        assert db.execute(f"select count(*) from {table}").fetchone()[0] == 0


# --- Phase 5: dose logs ---------------------------------------------------------------------


def _log(db, medicine_id, status="taken", at="2026-11-26 21:00+06"):
    return db.execute(
        "insert into dose_logs (medicine_id, scheduled_at, status, acted_at) "
        "values (%s, %s, %s, now()) on conflict (medicine_id, scheduled_at) "
        "do update set status = excluded.status returning id",
        (medicine_id, at, status),
    ).fetchone()[0]


def test_dose_logs_are_private_and_upsert_by_dose(db):
    alice, bob = new_user(db), new_user(db)
    with as_user(db, alice):
        med = _medicine(db, _prescription(db, "confirmed"))
        first = _log(db, med, "skipped")
        second = _log(db, med, "taken")  # same dose: replaces the earlier action
        assert first == second
        assert db.execute("select status from dose_logs").fetchone()[0] == "taken"
    with as_user(db, bob):
        assert db.execute("select count(*) from dose_logs").fetchone()[0] == 0
        with fails_with(db, psycopg.errors.InsufficientPrivilege):
            _log(db, med)


def test_dose_log_status_is_checked(db):
    user = new_user(db)
    with as_user(db, user):
        med = _medicine(db, _prescription(db, "confirmed"))
        with fails_with(db, psycopg.errors.CheckViolation):
            _log(db, med, status="maybe")


# --- Phase 7: account deletion ---------------------------------------------------------------


def test_users_can_delete_their_own_account_only(db):
    alice, bob = new_user(db), new_user(db)
    with as_user(db, alice):
        med = _medicine(db, _prescription(db, "confirmed"))
        _log(db, med)
    with as_user(db, bob):
        db.execute("select delete_my_account()")
    assert db.execute("select count(*) from auth.users where id = %s", (alice,)).fetchone()[0] == 1
    assert db.execute("select count(*) from auth.users where id = %s", (bob,)).fetchone()[0] == 0
    with as_user(db, alice):
        db.execute("select delete_my_account()")
    for table in ("profiles", "prescriptions", "medicines", "dose_logs"):
        assert db.execute(f"select count(*) from {table}").fetchone()[0] == 0


def test_anonymous_clients_cannot_delete_accounts(db):
    new_user(db)
    with as_user(db, None), fails_with(db, psycopg.errors.InsufficientPrivilege):
        db.execute("select delete_my_account()")


# --- Phase 9: insight columns ---------------------------------------------------------------


def test_active_medicines_include_insight_columns(db):
    user = new_user(db)
    with as_user(db, user):
        med = _medicine(db, _prescription(db, "confirmed"))
        db.execute(
            "update medicines set generic = 'Omeprazole', pills_on_hand = 20, "
            "pills_counted_at = now() where id = %s",
            (med,),
        )
        row = db.execute("select generic, pills_on_hand from active_medicines").fetchone()
    assert row == ("Omeprazole", 20)


def test_pill_count_cannot_be_negative(db):
    user = new_user(db)
    with as_user(db, user):
        med = _medicine(db, _prescription(db, "confirmed"))
        with fails_with(db, psycopg.errors.CheckViolation):
            db.execute("update medicines set pills_on_hand = -1 where id = %s", (med,))


# --- Hardening: privileged functions are not callable by signed-out clients -----------------


@pytest.mark.parametrize(
    "call",
    [
        "select accept_caregiver_invite('ABCDEFGH')",
        "select revoke_caregiver_link(gen_random_uuid())",
        "select confirm_prescription(gen_random_uuid())",
        "select is_caregiver_of(gen_random_uuid())",
        "select create_caregiver_invite('view')",
        "select delete_my_account()",
        "select set_reminder_channels(gen_random_uuid(), true, true, false)",
        "select set_training_consent(true)",
    ],
)
def test_anonymous_clients_cannot_call_privileged_functions(db, call):
    new_user(db)
    with as_user(db, None), fails_with(db, psycopg.errors.InsufficientPrivilege):
        db.execute(call)


def test_no_client_role_may_execute_the_sign_up_trigger(db):
    for role in ("anon", "authenticated"):
        allowed = db.execute(
            "select has_function_privilege(%s, 'public.handle_new_user()', 'execute')", (role,)
        ).fetchone()[0]
        assert not allowed, role
