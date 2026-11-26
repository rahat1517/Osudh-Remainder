"""Missed-dose alert job. Run every 5 minutes by a scheduler (cron, GitHub Actions, Supabase cron):

uv run python -m app.caregivers.job            # send alerts
uv run python -m app.caregivers.job --dry-run  # print what would be sent
"""

import argparse
import logging
from collections import defaultdict
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import psycopg

from app.caregivers.messages import missed_dose_text
from app.caregivers.missed import DEFAULT_GRACE, DEFAULT_LOOKBACK, find_missed
from app.caregivers.notifier import FcmNotifier, Notifier, PushMessage, RecordingNotifier
from app.caregivers.repository import CaregiverRepository
from app.config import get_settings

logger = logging.getLogger(__name__)


def run_once(
    repo: CaregiverRepository,
    notifier: Notifier,
    now: datetime,
    grace: timedelta = DEFAULT_GRACE,
    lookback: timedelta = DEFAULT_LOOKBACK,
) -> int:
    """Finds missed doses, alerts caregivers, records the alerts. Returns doses alerted."""
    alerted = 0
    for patient in repo.patients_with_caregivers(since=now - lookback - timedelta(days=1)):
        missed = find_missed(patient, now, grace, lookback)
        if not missed:
            continue
        caregivers = repo.caregivers_of(patient.patient_id)
        name = repo.patient_name(patient.patient_id) or ""
        tz = ZoneInfo(patient.settings.timezone)
        by_time: dict[datetime, list] = defaultdict(list)
        for dose in missed:
            by_time[dose.scheduled_at].append(dose)
        messages = []
        for at, doses in sorted(by_time.items()):
            clock = at.astimezone(tz).strftime("%H:%M")
            labels = [d.medicine_label for d in doses]
            for cg in caregivers:
                title, body = missed_dose_text(cg.locale, name, labels, clock)
                data = {
                    "type": "missed_dose",
                    "patient_id": patient.patient_id,
                    "at": at.isoformat(),
                }
                messages += [PushMessage(t, title, body, data) for t in cg.tokens]
        repo.delete_tokens(notifier.send(messages))
        # Recorded even without tokens, so a caregiver who installs later is not flooded
        repo.record_alerts(patient.patient_id, missed)
        alerted += len(missed)
    return alerted


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Send missed-dose alerts to caregivers")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO)
    settings = get_settings()
    if not settings.database_url:
        logger.error("DATABASE_URL is not set")
        return 2
    if args.dry_run or not settings.fcm_service_account_file:
        notifier: Notifier = RecordingNotifier()
    else:
        notifier = FcmNotifier(settings.fcm_service_account_file)
    with psycopg.connect(settings.database_url) as conn:
        count = run_once(CaregiverRepository(conn), notifier, datetime.now(UTC))
        if args.dry_run:
            conn.rollback()
        else:
            conn.commit()
    if isinstance(notifier, RecordingNotifier):
        for m in notifier.sent:
            logger.info("would send to %s…: %s / %s", m.token[:8], m.title, m.body)
    logger.info("missed doses alerted: %d", count)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
