// Differential test: Dart must give the same answer as Python for random inputs.
// Generate the input with backend/scripts/export_schedule_parity.py and pass its path in
// SCHEDULE_PARITY_VECTORS. Skipped when the variable is not set (CI runs it in its own job).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/schedule/schedule_engine.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';

DateTime _wall(String iso) {
  final d = DateTime.parse(iso);
  return DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);
}

String? _fmt(DateTime? d) {
  if (d == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}';
}

String _fmtTime(DoseTime t) {
  final suffix = t.dayOffset > 0 ? '+${t.dayOffset}' : '';
  return '${t.clock}$suffix ${t.amount} ${t.slot.name}';
}

ScheduleSettings _settings(Map<String, dynamic>? o) {
  const d = ScheduleSettings();
  o ??= const {};
  int clock(String key, int fallback) =>
      o!.containsKey(key) ? parseClock(o[key] as String) : fallback;
  return ScheduleSettings(
    breakfast: clock('breakfast', d.breakfast),
    lunch: clock('lunch', d.lunch),
    evening: clock('evening', d.evening),
    dinner: clock('dinner', d.dinner),
    bedtime: clock('bedtime', d.bedtime),
    offsetBeforeMeal: o['offset_before_meal'] as int? ?? d.offsetBeforeMeal,
    offsetAfterMeal: o['offset_after_meal'] as int? ?? d.offsetAfterMeal,
    offsetEmptyStomach:
        o['offset_empty_stomach'] as int? ?? d.offsetEmptyStomach,
    groupWindowMinutes:
        o['group_window_minutes'] as int? ?? d.groupWindowMinutes,
  );
}

MedicineInput _medicine(Map<String, dynamic> m, {String? start}) =>
    MedicineInput(
      id: m['id'] as String? ?? 'm',
      start: _wall((m['start'] ?? start) as String),
      dosePattern: m['dose_pattern'] as String?,
      intervalHours: m['interval_hours'] as int?,
      intervalAmount: m['interval_amount'] as String? ?? '1',
      timing: timingFromJson(m['timing'] as String? ?? 'not_specified'),
      durationDays: m['duration_days'] as int?,
      weekdays: (m['weekdays'] as List?)?.cast<int>(),
      asNeeded: m['as_needed'] as bool? ?? false,
    );

void main() {
  final path = Platform.environment['SCHEDULE_PARITY_VECTORS'];
  test('Dart and Python engines agree on random inputs', () {
    final cases =
        (jsonDecode(File(path!).readAsStringSync())
                as Map<String, dynamic>)['medicine_cases']
            as List;
    expect(cases, isNotEmpty);
    final mismatches = <String>[];
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final settings = _settings(c['settings'] as Map<String, dynamic>?);
      final med = _medicine(c['medicine'] as Map<String, dynamic>);
      final want = c['expect'] as Map<String, dynamic>;
      Map<String, dynamic> got;
      try {
        final r = scheduleMedicine(med, settings);
        final end = med.start.add(Duration(days: c['window_days'] as int));
        got = {
          'daily_times': r.dailyTimes.map(_fmtTime).toList(),
          'doses_per_day': r.dosesPerDay,
          'total_doses': r.totalDoses,
          'first_dose_at': _fmt(r.firstDoseAt),
          'last_dose_at': _fmt(r.lastDoseAt),
          'occurrences': occurrencesBetween(
            [med],
            settings,
            med.start,
            end,
          ).map((o) => '${_fmt(o.at)} ${o.amount}').toList(),
        };
      } on ScheduleException catch (e) {
        got = {'error': e.code};
      }
      if (jsonEncode(got) != jsonEncode(want)) {
        mismatches.add(
          '${c['id']}: ${jsonEncode(c['medicine'])}\n  python: ${jsonEncode(want)}\n  dart:   ${jsonEncode(got)}',
        );
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.take(5).join('\n'));
  }, skip: path == null ? 'SCHEDULE_PARITY_VECTORS not set' : false);
}
