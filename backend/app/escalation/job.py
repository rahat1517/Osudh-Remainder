"""SMS and voice-call reminder job. Run every 5 minutes with the missed-dose job:

uv run python -m app.escalation.job            # send
uv run python -m app.escalation.job --dry-run  # print what would be sent
"""

import argparse
import logging
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import psycopg

from app.config import get_settings
from app.escalation.engine import DEFAULT_LIMITS, LOOKBACK, Limits, plan_escalations, sms_segments
from app.escalation.gateways import (
    HttpSmsGateway,
    HttpVoiceGateway,
    RecordingGateway,
    SmsGateway,
    VoiceGateway,
)
from app.escalation.repository import EscalationRepository

logger = logging.getLogger(__name__)
DHAKA = ZoneInfo("Asia/Dhaka")


@dataclass(frozen=True)
class Pricing:
    sms_segment_bdt: float = 0.35
    call_bdt: float = 1.0
    monthly_budget_bdt: float = 5000.0


DEFAULT_PRICING = Pricing()


@dataclass
class JobResult:
    sent: int = 0
    failed: int = 0
    skipped: int = 0


def run_once(
    repo: EscalationRepository,
    sms: SmsGateway,
    voice: VoiceGateway,
    now: datetime,
    limits: Limits = DEFAULT_LIMITS,
    pricing: Pricing = DEFAULT_PRICING,
) -> JobResult:
    local = now.astimezone(DHAKA)
    day_start = local.replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = day_start.replace(day=1)
    spend = repo.month_spend(month_start)
    result = JobResult()
    for patient in repo.patients(since=now - LOOKBACK - timedelta(days=1), day_start=day_start):
        for out in plan_escalations(patient, now, limits):
            cost = (
                sms_segments(out.text) * pricing.sms_segment_bdt
                if out.channel == "sms"
                else pricing.call_bdt
            )
            if out.over_limit or spend + cost > pricing.monthly_budget_bdt:
                repo.record(out, "skipped_limit", None, 0)
                result.skipped += 1
                continue
            if out.channel == "sms":
                sent = sms.send_sms(out.phone, out.text)
            else:
                sent = voice.place_call(out.phone, out.text, patient.locale)
            if sent.ok:
                spend += cost
                result.sent += 1
                repo.record(out, "sent", sent.provider_id, cost)
            else:
                logger.warning("%s to patient failed: %s", out.channel, sent.error)
                result.failed += 1
                repo.record(out, "failed", None, 0)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Send SMS and voice-call medicine reminders")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO)
    s = get_settings()
    if not s.database_url:
        logger.error("DATABASE_URL is not set")
        return 2
    recorder = RecordingGateway()
    sms: SmsGateway = recorder
    voice: VoiceGateway = recorder
    if not args.dry_run:
        if s.sms_gateway_url and s.sms_api_key:
            sms = HttpSmsGateway(s.sms_gateway_url, s.sms_api_key, s.sms_sender_id or "")
        if s.voice_gateway_url and s.voice_api_key:
            voice = HttpVoiceGateway(s.voice_gateway_url, s.voice_api_key)
    limits = Limits(s.max_sms_per_patient_day, s.max_calls_per_patient_day)
    pricing = Pricing(s.sms_segment_bdt, s.call_bdt, s.escalation_monthly_budget_bdt)
    with psycopg.connect(s.database_url) as conn:
        result = run_once(
            EscalationRepository(conn), sms, voice, datetime.now(UTC), limits, pricing
        )
        conn.rollback() if args.dry_run else conn.commit()
    for to, text in recorder.sms:
        logger.info("SMS (not sent: no gateway or dry run) to …%s: %s", to[-4:], text)
    for to, text, _ in recorder.calls:
        logger.info("Call (not placed) to …%s: %s", to[-4:], text)
    logger.info("sent=%d failed=%d skipped=%d", result.sent, result.failed, result.skipped)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
