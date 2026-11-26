// Runs the shared conformance suite (spec/schedule/vectors.json) against the Dart engine.
// The Python implementation runs the same file in backend/tests/test_schedule_conformance.py.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/schedule/schedule_engine.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';

final _vectors = jsonDecode(
  File('../spec/schedule/vectors.json').readAsStringSync(),
) as Map<String, dynamic>;

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
  group('medicine cases', () {
    for (final raw in _vectors['medicine_cases'] as List) {
      final c = raw as Map<String, dynamic>;
      test(c['id'], () {
        final settings = _settings(c['settings'] as Map<String, dynamic>?);
        final med = _medicine(c['medicine'] as Map<String, dynamic>);
        final expect_ = c['expect'] as Map<String, dynamic>;

        if (expect_.containsKey('error')) {
          expect(
            () => scheduleMedicine(med, settings),
            throwsA(
              isA<ScheduleException>().having(
                (e) => e.code,
                'code',
                expect_['error'],
              ),
            ),
          );
          return;
        }

        final r = scheduleMedicine(med, settings);
        if (expect_.containsKey('daily_times')) {
          expect(r.dailyTimes.map(_fmtTime).toList(), expect_['daily_times']);
        }
        if (expect_.containsKey('doses_per_day')) {
          expect(r.dosesPerDay, expect_['doses_per_day']);
        }
        if (expect_.containsKey('total_doses')) {
          expect(r.totalDoses, expect_['total_doses']);
        }
        if (expect_.containsKey('first_dose_at')) {
          expect(_fmt(r.firstDoseAt), expect_['first_dose_at']);
        }
        if (expect_.containsKey('last_dose_at')) {
          expect(_fmt(r.lastDoseAt), expect_['last_dose_at']);
        }
        if (expect_.containsKey('occurrences')) {
          final end = med.start.add(
            Duration(days: c['window_days'] as int? ?? 7),
          );
          final occ = occurrencesBetween([med], settings, med.start, end);
          expect(
            occ.map((o) => '${_fmt(o.at)} ${o.amount}').toList(),
            expect_['occurrences'],
          );
        }
      });
    }
  });

  group('grouping cases', () {
    for (final raw in _vectors['grouping_cases'] as List) {
      final c = raw as Map<String, dynamic>;
      test(c['id'], () {
        final settings = _settings(c['settings'] as Map<String, dynamic>?);
        final start = _wall(c['start'] as String);
        final meds = [
          for (final m in c['medicines'] as List)
            _medicine(m as Map<String, dynamic>, start: c['start'] as String),
        ];
        final end = start.add(Duration(days: c['window_days'] as int));
        final reminders = groupReminders(
          occurrencesBetween(meds, settings, start, end),
          settings.groupWindowMinutes,
        );
        expect(
          reminders
              .map(
                (r) =>
                    '${_fmt(r.at)} ${r.items.map((i) => i.medicineId).join(',')}',
              )
              .toList(),
          c['expect_reminders'],
        );
      });
    }
  });
}
