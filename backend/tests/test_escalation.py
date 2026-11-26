from datetime import UTC, datetime, timedelta

import httpx2

from app.escalation.engine import Limits, PatientChannels, plan_escalations, sms_segments
from app.escalation.gateways import HttpSmsGateway, HttpVoiceGateway, local_number
from app.prescriptions.schemas import Timing
from app.schedule.models import MedicineInput, ScheduleSettings

DHAKA = timedelta(hours=6)


def at(day, hour, minute=0):
    return datetime(2026, 11, day, hour, minute, tzinfo=UTC) - DHAKA


def patient(**overrides):
    data = dict(
        patient_id="p",
        phone="+8801712345678",
        locale="bn",
        sms=True,
        call=True,
        feature_phone=False,
        settings=ScheduleSettings(),
        medicines=[
            MedicineInput(
                id="seclo",
                dose_pattern="1+0+1",
                timing=Timing.BEFORE_MEAL,
                duration_days=30,
                start=at(25, 6),
            ),
            MedicineInput(
                id="napa",
                dose_pattern="1+1+1",
                timing=Timing.BEFORE_MEAL,
                duration_days=5,
                start=at(25, 6),
            ),
        ],
        labels={"seclo": "Seclo 20 mg", "napa": "Napa 500 mg"},
    )
    data.update(overrides)
    return PatientChannels(**data)


def summary(out):
    return [(o.channel, o.reason, o.medicine_ids, o.over_limit) for o in out]


def test_missed_dose_gets_sms_at_30_and_call_at_45_minutes():
    # Both are due 21:00 before dinner
    assert plan_escalations(patient(), at(26, 21, 29)) == []
    assert summary(plan_escalations(patient(), at(26, 21, 31))) == [
        ("sms", "missed", ("napa", "seclo"), False)
    ]
    out = plan_escalations(patient(), at(26, 21, 46))
    assert summary(out) == [
        ("sms", "missed", ("napa", "seclo"), False),
        ("call", "missed", ("napa", "seclo"), False),
    ]
    assert out[0].text.startswith("ওষুধ রিমাইন্ডার: ২১:০০-এর Napa 500 mg, Seclo 20 mg")


def test_taken_doses_and_already_sent_messages_are_skipped():
    taken = {("seclo", at(26, 21)), ("napa", at(26, 21))}
    assert plan_escalations(patient(handled=taken), at(26, 21, 46)) == []
    sent = {(m, at(26, 21), "sms", "missed") for m in ("seclo", "napa")}
    assert summary(plan_escalations(patient(already=sent), at(26, 21, 46))) == [
        ("call", "missed", ("napa", "seclo"), False)
    ]


def test_feature_phone_mode_reminds_at_dose_time():
    p = patient(feature_phone=True, call=False)
    assert plan_escalations(p, at(26, 20, 59)) == []
    out = plan_escalations(p, at(26, 21, 3))
    assert summary(out) == [("sms", "reminder", ("napa", "seclo"), False)]
    assert "খাওয়ার সময়" in out[0].text
    # No "missed" escalation in feature-phone mode (the patient cannot tap Taken)
    assert plan_escalations(p, at(26, 21, 50)) == []


def test_daily_limits_mark_extra_messages():
    out = plan_escalations(patient(sent_today={"sms": 6, "call": 2}), at(26, 21, 46), Limits(6, 3))
    assert summary(out) == [
        ("sms", "missed", ("napa", "seclo"), True),
        ("call", "missed", ("napa", "seclo"), False),
    ]


def test_opted_out_patients_get_nothing():
    assert plan_escalations(patient(sms=False, call=False), at(26, 21, 46)) == []


def test_english_text():
    out = plan_escalations(patient(locale="en", call=False), at(26, 21, 31))
    assert out[0].text.startswith("Oshudh Reminder: Napa 500 mg, Seclo 20 mg due at 21:00")


def test_sms_segments_account_for_bangla():
    assert sms_segments("a" * 160) == 1
    assert sms_segments("a" * 161) == 2
    assert sms_segments("আ" * 70) == 1
    assert sms_segments("আ" * 71) == 2


def test_http_sms_gateway_request_and_response():
    seen = {}

    def handler(request):
        seen["body"] = request.content.decode()
        return httpx2.Response(200, json={"response_code": 202, "message_id": "m-1"})

    gw = HttpSmsGateway(
        "https://sms.example/api",
        "KEY",
        "OSHUDH",
        httpx2.Client(transport=httpx2.MockTransport(handler)),
    )
    result = gw.send_sms("+8801712345678", "test")
    assert result.ok and result.provider_id == "m-1"
    assert "number=8801712345678" in seen["body"] and "senderid=OSHUDH" in seen["body"]

    failing = HttpSmsGateway(
        "https://x",
        "K",
        "S",
        httpx2.Client(transport=httpx2.MockTransport(lambda r: httpx2.Response(500))),
    )
    assert not failing.send_sms("+8801712345678", "x").ok


def test_http_voice_gateway():
    def handler(request):
        assert request.headers["authorization"] == "Bearer K"
        return httpx2.Response(200, json={"id": "c-9"})

    gw = HttpVoiceGateway(
        "https://ivr.example", "K", httpx2.Client(transport=httpx2.MockTransport(handler))
    )
    assert gw.place_call("+8801712345678", "text", "bn").provider_id == "c-9"
    assert local_number("+8801712345678") == "8801712345678"
