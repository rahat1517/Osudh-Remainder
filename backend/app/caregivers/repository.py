"""Database access for the missed-dose job. Runs with a privileged connection (server only)."""

from dataclasses import dataclass
from datetime import datetime

import psycopg

from app.caregivers.missed import MissedDose, PatientSnapshot
from app.prescriptions.schemas import Timing
from app.schedule.models import MedicineInput, ScheduleSettings


@dataclass(frozen=True)
class CaregiverContact:
    caregiver_id: str
    locale: str
    tokens: list[str]


class CaregiverRepository:
    def __init__(self, conn: psycopg.Connection):
        self._db = conn

    def patients_with_caregivers(self, since: datetime) -> list[PatientSnapshot]:
        """Patients with at least one active caregiver, and what is needed to find missed doses."""
        patients = self._db.execute(
            """
            select p.id, p.timezone, p.breakfast, p.lunch, p.evening, p.dinner, p.bedtime
              from profiles p
             where exists (select 1 from caregiver_links l
                            where l.patient_id = p.id and l.status = 'active')
            """
        ).fetchall()
        snapshots = []
        for pid, tz, breakfast, lunch, evening, dinner, bedtime in patients:
            settings = ScheduleSettings(
                breakfast=breakfast,
                lunch=lunch,
                evening=evening,
                dinner=dinner,
                bedtime=bedtime,
                timezone=tz,
            )
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
                weekdays,
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
                        weekdays=weekdays,
                        as_needed=prn,
                        start=start,
                    )
                )
                labels[mid] = f"{name} {strength}" if strength else name
            handled = self._db.execute(
                """
                select medicine_id::text, scheduled_at from dose_logs
                 where user_id = %s and scheduled_at >= %s
                union
                select medicine_id::text, scheduled_at from missed_dose_alerts
                 where patient_id = %s and scheduled_at >= %s
                """,
                (pid, since, pid, since),
            ).fetchall()
            snapshots.append(
                PatientSnapshot(
                    str(pid), settings, medicines, labels, {(m, at) for m, at in handled}
                )
            )
        return snapshots

    def patient_name(self, patient_id: str) -> str | None:
        row = self._db.execute(
            "select display_name from profiles where id = %s", (patient_id,)
        ).fetchone()
        return row[0] if row else None

    def caregivers_of(self, patient_id: str) -> list[CaregiverContact]:
        rows = self._db.execute(
            """
            select l.caregiver_id::text, p.locale,
                   coalesce(array_agg(t.token) filter (where t.token is not null), '{}')
              from caregiver_links l
              join profiles p on p.id = l.caregiver_id
              left join push_tokens t on t.user_id = l.caregiver_id
             where l.patient_id = %s and l.status = 'active'
             group by l.caregiver_id, p.locale
            """,
            (patient_id,),
        ).fetchall()
        return [CaregiverContact(cid, locale, list(tokens)) for cid, locale, tokens in rows]

    def record_alerts(self, patient_id: str, doses: list[MissedDose]) -> None:
        with self._db.cursor() as cur:
            cur.executemany(
                "insert into missed_dose_alerts (medicine_id, scheduled_at, patient_id) "
                "values (%s, %s, %s) on conflict do nothing",
                [(d.medicine_id, d.scheduled_at, patient_id) for d in doses],
            )

    def delete_tokens(self, tokens: list[str]) -> None:
        if tokens:
            self._db.execute("delete from push_tokens where token = any(%s)", (tokens,))
