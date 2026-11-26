"""SMS/call job against the real schema."""

from datetime import UTC, datetime, timedelta

from app.escalation.engine import Limits
from app.escalation.gateways import RecordingGateway
from app.escalation.job import Pricing, run_once
from app.escalation.repository import EscalationRepository

from .conftest import as_user, new_user
from .test_rls import _medicine, _prescription

DHAKA = timedelta(hours=6)


def at(day, hour, minute=0):
    return datetime(2026, 11, day, hour, minute, tzinfo=UTC) - DHAKA


def _patient(db, sms=True, call=True, feature_phone=False):
    user = new_user(db)
    db.execute("update auth.users set phone = '8801712345678' where id = %s", (user,))
    with as_user(db, user):
        med = _medicine(db, _prescription(db, "confirmed"))
        db.execute("update medicines set start_at = %s where id = %s", (at(25, 6), med))
        db.execute("select set_reminder_channels(%s, %s, %s, %s)", (user, sms, call, feature_phone))
    return user, med


def test_job_sends_once_and_records_cost(db):
    _patient(db)
    repo, gw = EscalationRepository(db), RecordingGateway()
    result = run_once(repo, gw, gw, at(26, 21, 46))
    assert (result.sent, result.failed, result.skipped) == (2, 0, 0)
    assert gw.sms[0][0] == "+8801712345678" and "২১:০০" in gw.sms[0][1]
    assert len(gw.calls) == 1
    costs = dict(db.execute("select channel, cost_bdt from escalation_events").fetchall())
    assert float(costs["call"]) == 1.0 and float(costs["sms"]) > 0
    again = run_once(repo, gw, gw, at(26, 21, 50))
    assert (again.sent, again.skipped) == (0, 0)


def test_opted_out_patients_are_not_contacted(db):
    _patient(db, sms=False, call=False)
    gw = RecordingGateway()
    assert run_once(EscalationRepository(db), gw, gw, at(26, 21, 46)).sent == 0


def test_budget_and_limits_skip_instead_of_sending(db):
    _patient(db)
    gw = RecordingGateway()
    result = run_once(EscalationRepository(db), gw, gw, at(26, 21, 46), Limits(0, 0), Pricing())
    assert (result.sent, result.skipped) == (0, 2)
    statuses = {r[0] for r in db.execute("select status from escalation_events").fetchall()}
    assert statuses == {"skipped_limit"}
    assert gw.sms == [] and gw.calls == []


def test_failed_sends_are_recorded(db):
    _patient(db, call=False)
    gw = RecordingGateway(fail=True)
    result = run_once(EscalationRepository(db), gw, gw, at(26, 21, 46))
    assert result.failed == 1
    assert db.execute("select status from escalation_events").fetchone()[0] == "failed"
