/// Turns medicines into concrete alarms for the next days. Pure and deterministic.
library;

import '../data/models.dart';
import '../schedule/schedule_engine.dart';
import '../schedule/schedule_models.dart';
import 'dose_log.dart';

/// Alarms are scheduled this many days ahead and rolled forward whenever the app runs or the
/// user acts on an alarm.
const alarmHorizonDays = 7;

/// Upper bound on scheduled alarms (Android allows several hundred per app; stay well below).
const maxAlarms = 150;

/// Fixed id of the "open the app to keep reminders running" notice at the end of the horizon.
const horizonNoticeId = 1;

class AlarmItem {
  const AlarmItem(this.medicineId, this.label, this.amount);

  final String medicineId;
  final String label;
  final String amount;
}

class AlarmSpec {
  const AlarmSpec({
    required this.id,
    required this.at,
    required this.items,
    this.isHorizonNotice = false,
  });

  final int id;

  /// Wall-clock time (UTC container).
  final DateTime at;
  final List<AlarmItem> items;
  final bool isHorizonNotice;
}

/// 31-bit FNV-1a hash: a stable notification id for the same reminder across re-plans.
int stableAlarmId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final id = hash & 0x7fffffff;
  return id <= horizonNoticeId ? id + 2 : id;
}

/// Alarms from [wallNow] for [horizonDays] days. Doses already logged in [handledKeys]
/// (taken or skipped) are left out; a reminder whose doses are all handled is dropped.
List<AlarmSpec> planAlarms({
  required List<Medicine> medicines,
  required ScheduleSettings settings,
  required DateTime wallNow,
  Set<String> handledKeys = const {},
  Duration utcOffset = const Duration(hours: 6),
  int horizonDays = alarmHorizonDays,
}) {
  if (medicines.isEmpty) return const [];
  final byId = {for (final m in medicines) m.id: m};
  final end = wallNow.add(Duration(days: horizonDays));
  final occurrences = occurrencesBetween(
    [for (final m in medicines) m.toScheduleInput(utcOffset: utcOffset)],
    settings,
    wallNow,
    end,
  ).where((o) => !handledKeys.contains(doseKey(o.medicineId, o.at))).toList();

  final alarms = <AlarmSpec>[];
  for (final r in groupReminders(occurrences, settings.groupWindowMinutes)) {
    final ids = [for (final o in r.items) o.medicineId]..sort();
    alarms.add(
      AlarmSpec(
        id: stableAlarmId('${r.at.toIso8601String()}|${ids.join(',')}'),
        at: r.at,
        items: [
          for (final o in r.items)
            AlarmItem(o.medicineId, byId[o.medicineId]!.label, o.amount),
        ],
      ),
    );
    if (alarms.length == maxAlarms) break;
  }
  if (alarms.isEmpty) return alarms;

  // Remind the user to open the app before the scheduled alarms run out.
  final last = alarms.last.at;
  final noticeDay = DateTime.utc(last.year, last.month, last.day, 20);
  final noticeAt = noticeDay.isAfter(wallNow) ? noticeDay : last;
  alarms.add(
    AlarmSpec(
      id: horizonNoticeId,
      at: noticeAt,
      items: const [],
      isHorizonNotice: true,
    ),
  );
  return alarms;
}
