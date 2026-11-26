"""Decides which SMS and voice-call reminders to send now (pure; no I/O).

Rules (per patient, opt-in):
- feature-phone mode: reminder at dose time, by SMS and/or call (the patient has no app alarms)
- escalation: dose still not taken 30 min after it was due → SMS; 45 min → voice call
Each (medicine, dose time, channel, reason) is sent at most once. Daily per-patient limits cap cost;
attempts over the limit are recorded as skipped so they are not retried.
"""

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from app.schedule.engine import occurrences_for
from app.schedule.models import MedicineInput, ScheduleSettings

REMINDER_WINDOW = timedelta(minutes=15)  # job runs every 5 min; tolerate delays
SMS_AFTER = timedelta(minutes=30)
CALL_AFTER = timedelta(minutes=45)
LOOKBACK = timedelta(hours=6)


@dataclass(frozen=True)
class Limits:
    sms_per_day: int = 6
    calls_per_day: int = 3


DEFAULT_LIMITS = Limits()


@dataclass
class PatientChannels:
    patient_id: str
    phone: str
    locale: str
    sms: bool
    call: bool
    feature_phone: bool
    settings: ScheduleSettings
    medicines: list[MedicineInput]
    labels: dict[str, str]
    handled: set[tuple[str, datetime]] = field(default_factory=set)  # taken/skipped doses
    already: set[tuple[str, datetime, str, str]] = field(default_factory=set)  # sent attempts
    sent_today: dict[str, int] = field(default_factory=dict)  # channel → count


@dataclass(frozen=True)
class Outgoing:
    patient_id: str
    phone: str
    channel: str  # sms | call
    reason: str  # reminder | missed
    scheduled_at: datetime
    medicine_ids: tuple[str, ...]
    text: str
    over_limit: bool


def _key(medicine_id: str, at: datetime) -> tuple[str, datetime]:
    return medicine_id, at.astimezone(UTC).replace(second=0, microsecond=0)


_BN_DIGITS = str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯")

TEXTS = {
    ("bn", "reminder"): "ওষুধ রিমাইন্ডার: {time}-এ {medicines} খাওয়ার সময়।",
    (
        "bn",
        "missed",
    ): "ওষুধ রিমাইন্ডার: {time}-এর {medicines} এখনো খাওয়া হয়নি বলে জানা গেছে। খেয়ে থাকলে অ্যাপে জানান।",
    ("en", "reminder"): "Oshudh Reminder: time to take {medicines} ({time}).",
    (
        "en",
        "missed",
    ): "Oshudh Reminder: {medicines} due at {time} is not marked as taken. If you took it, tap Taken in the app.",
}


def message_text(locale: str, reason: str, medicines: list[str], time: str) -> str:
    template = TEXTS.get((locale, reason), TEXTS[("bn", reason)])
    if locale == "bn":
        time = time.translate(_BN_DIGITS)
    return template.format(medicines=", ".join(medicines), time=time)


def plan_escalations(
    p: PatientChannels, now: datetime, limits: Limits = Limits()
) -> list[Outgoing]:
    if not p.medicines or not (p.sms or p.call):
        return []
    tz = ZoneInfo(p.settings.timezone)
    handled = {_key(m, at) for m, at in p.handled}
    occurrences = occurrences_for(
        p.medicines, p.settings, now - LOOKBACK, now + timedelta(seconds=1)
    )

    wanted: list[tuple[str, str, datetime, str]] = []  # (channel, reason, at, medicine_id)
    for o in occurrences:
        if _key(o.medicine_id, o.at) in handled:
            continue
        overdue = now - o.at
        channels: list[tuple[str, str]] = []
        if p.feature_phone and timedelta(0) <= overdue <= REMINDER_WINDOW:
            channels += [(c, "reminder") for c, on in (("sms", p.sms), ("call", p.call)) if on]
        if not p.feature_phone:
            if p.sms and overdue >= SMS_AFTER:
                channels.append(("sms", "missed"))
            if p.call and overdue >= CALL_AFTER:
                channels.append(("call", "missed"))
        for channel, reason in channels:
            mid, at = _key(o.medicine_id, o.at)
            if (mid, at, channel, reason) not in p.already:
                wanted.append((channel, reason, o.at, o.medicine_id))

    grouped: dict[tuple[str, str, datetime], list[str]] = defaultdict(list)
    for channel, reason, at, mid in wanted:
        grouped[(channel, reason, at)].append(mid)

    counts = dict(p.sent_today)
    out: list[Outgoing] = []
    for (channel, reason, at), mids in sorted(grouped.items(), key=lambda kv: kv[0][2]):
        cap = limits.sms_per_day if channel == "sms" else limits.calls_per_day
        over = counts.get(channel, 0) >= cap
        if not over:
            counts[channel] = counts.get(channel, 0) + 1
        clock = at.astimezone(tz).strftime("%H:%M")
        text = message_text(p.locale, reason, [p.labels.get(m, "") for m in mids], clock)
        out.append(
            Outgoing(p.patient_id, p.phone, channel, reason, at, tuple(sorted(mids)), text, over)
        )
    return out


def sms_segments(text: str) -> int:
    """GSM-7 fits 160 chars (153 when split); Bangla needs UCS-2: 70 chars (67 when split)."""
    unicode = any(ord(ch) > 127 for ch in text)
    single, multi = (70, 67) if unicode else (160, 153)
    return 1 if len(text) <= single else -(-len(text) // multi)
