"""Database access for the SMS/call job (privileged server connection)."""

from datetime import datetime

import psycopg

from app.escalation.engine import Outgoing, PatientChannels
from app.prescriptions.schemas import Timing
from app.schedule.models import MedicineInput, ScheduleSettings


class EscalationRepository:
    def __init__(self, conn: psycopg.Connection):
        self._db = conn

    def patients(self, since: datetime, day_start: datetime) -> list[PatientChannels]:
        rows = self._db.execute(
            """
            select p.id, u.phone, p.locale, p.sms_reminders, p.call_reminders, p.feature_phone_mode,
                   p.timezone, p.breakfast, p.lunch, p.evening, p.dinner, p.bedtime
              from profiles p join auth.users u on u.id = p.id
             where (p.sms_reminders or p.call_reminders) and u.phone is not null
            """
        ).fetchall()
        result = []
        for pid, phone, locale, sms, call, fp, tz, b, lu, ev, di, be in rows:
            meds = self._db.execute(
                """
                select id::text, name, strength, dose_pattern, interval_hours, interval_amount,
                       timing, duration_days, weekdays, as_needed, start_at
                  from active_medicines where user_id = %s
                """,
                (pid,),
            ).fetchall()
            medicines, labels = [], {}
            for (
                mid,
                name,
                strength,
                pattern,
                interval,
                amount,
                timing,
                days,
                wd,
                prn,
                start,
            ) in meds:
                medicines.append(
                    MedicineInput(
                        id=mid,
                        dose_pattern=pattern,
                        interval_hours=interval,
                        interval_amount=amount,
                        timing=Timing(timing),
                        duration_days=days,
                        weekdays=wd,
                        as_needed=prn,
                        start=start,
                    )
                )
                labels[mid] = f"{name} {strength}" if strength else name
            handled = self._db.execute(
                "select medicine_id::text, scheduled_at from dose_logs where user_id = %s and scheduled_at >= %s",
                (pid, since),
            ).fetchall()
            already = self._db.execute(
                "select medicine_id::text, scheduled_at, channel, reason from escalation_events "
                "where patient_id = %s and scheduled_at >= %s",
                (pid, since),
            ).fetchall()
            counts = dict(
                self._db.execute(
                    "select channel, count(*) from escalation_events "
                    "where patient_id = %s and created_at >= %s and status = 'sent' group by channel",
                    (pid, day_start),
                ).fetchall()
            )
            result.append(
                PatientChannels(
                    patient_id=str(pid),
                    phone=phone if phone.startswith("+") else f"+{phone}",
                    locale=locale,
                    sms=sms,
                    call=call,
                    feature_phone=fp,
                    settings=ScheduleSettings(
                        breakfast=b, lunch=lu, evening=ev, dinner=di, bedtime=be, timezone=tz
                    ),
                    medicines=medicines,
                    labels=labels,
                    handled={(m, at) for m, at in handled},
                    already={(m, at, c, r) for m, at, c, r in already},
                    sent_today=counts,
                )
            )
        return result

    def month_spend(self, month_start: datetime) -> float:
        row = self._db.execute(
            "select coalesce(sum(cost_bdt), 0) from escalation_events where created_at >= %s",
            (month_start,),
        ).fetchone()
        return float(row[0])

    def record(self, out: Outgoing, status: str, provider_id: str | None, cost: float) -> None:
        with self._db.cursor() as cur:
            cur.executemany(
                """
                insert into escalation_events
                    (patient_id, medicine_id, scheduled_at, channel, reason, status, provider_id, cost_bdt)
                values (%s, %s, %s, %s, %s, %s, %s, %s)
                on conflict (medicine_id, scheduled_at, channel, reason) do nothing
                """,
                [
                    # The cost of a grouped message is attributed to its first medicine
                    (
                        out.patient_id,
                        mid,
                        out.scheduled_at,
                        out.channel,
                        out.reason,
                        status,
                        provider_id,
                        cost if i == 0 else 0,
                    )
                    for i, mid in enumerate(out.medicine_ids)
                ],
            )
