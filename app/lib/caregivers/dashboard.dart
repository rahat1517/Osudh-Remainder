/// Status of a patient's doses today, for the caregiver dashboard. Pure and deterministic.
library;

import '../alarms/dose_log.dart';
import '../schedule/schedule_engine.dart';
import 'caregiver_models.dart';

/// Same grace period as the server's missed-dose job.
const missedAfter = Duration(minutes: 30);

enum DoseState { taken, skipped, missed, due, upcoming }

class DoseRow {
  const DoseRow(this.at, this.label, this.amount, this.state);

  final DateTime at; // wall clock
  final String label;
  final String amount;
  final DoseState state;
}

List<DoseRow> todaysDoses(
  PatientSnapshot p,
  DateTime wallNow, {
  Duration utcOffset = const Duration(hours: 6),
}) {
  final dayStart = DateTime.utc(wallNow.year, wallNow.month, wallNow.day);
  final byId = {for (final m in p.medicines) m.id: m};
  final logged = {for (final l in p.logs) l.key: l.status};
  final occurrences = occurrencesBetween(
    [for (final m in p.medicines) m.toScheduleInput(utcOffset: utcOffset)],
    p.settings,
    dayStart,
    dayStart.add(const Duration(days: 1)),
  );
  return [
    for (final o in occurrences)
      DoseRow(o.at, byId[o.medicineId]!.label, o.amount, switch (logged[doseKey(
        o.medicineId,
        o.at,
      )]) {
        DoseStatus.taken => DoseState.taken,
        DoseStatus.skipped => DoseState.skipped,
        null when !wallNow.isBefore(o.at.add(missedAfter)) => DoseState.missed,
        null when !wallNow.isBefore(o.at) => DoseState.due,
        null => DoseState.upcoming,
      }),
  ];
}
