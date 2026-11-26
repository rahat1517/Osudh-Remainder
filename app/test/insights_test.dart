import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/alarms/dose_log.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/insights/insights.dart';
import 'package:oshudh_reminder/insights/prayer_times.dart';
import 'package:oshudh_reminder/insights/ramadan.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';

const settings = ScheduleSettings();
final wallNow = DateTime.utc(2026, 11, 26, 10);

Medicine med(
  String id,
  String pattern, {
  Timing timing = Timing.notSpecified,
  int? days,
  String? generic,
  double? pills,
  DateTime? counted,
  bool asNeeded = false,
}) => Medicine(
  id: id,
  name: id,
  dosePattern: pattern,
  timing: timing,
  durationDays: days,
  generic: generic,
  pillsOnHand: pills,
  pillsCountedAt: counted,
  asNeeded: asNeeded,
  startAt: DateTime.utc(2026, 11, 10),
);

DoseLog taken(String id, DateTime scheduledWall, int lateMinutes) => DoseLog(
  medicineId: id,
  scheduledAt: scheduledWall,
  status: DoseStatus.taken,
  // acted at (wall + late) converted to a real instant (UTC = wall − 6 h)
  actedAt: scheduledWall
      .add(Duration(minutes: lateMinutes))
      .subtract(const Duration(hours: 6)),
);

void main() {
  group('meal-time learning', () {
    final m = med('amlo', '0+0+1'); // dinner 21:30

    test('three late days suggest moving dinner by the median delay', () {
      final logs = [
        taken('amlo', DateTime.utc(2026, 11, 23, 21, 30), 40),
        taken('amlo', DateTime.utc(2026, 11, 24, 21, 30), 45),
        taken('amlo', DateTime.utc(2026, 11, 25, 21, 30), 50),
      ];
      final s = suggestMealShifts(
        logs: logs,
        medicines: [m],
        settings: settings,
        wallNow: wallNow,
      ).single;
      expect(
        (s.meal, s.from, s.to, s.days),
        ('dinner', 21 * 60 + 30, 22 * 60 + 15, 3),
      );
    });

    test('two days are not enough evidence', () {
      final logs = [
        taken('amlo', DateTime.utc(2026, 11, 24, 21, 30), 45),
        taken('amlo', DateTime.utc(2026, 11, 25, 21, 30), 45),
      ];
      expect(
        suggestMealShifts(
          logs: logs,
          medicines: [m],
          settings: settings,
          wallNow: wallNow,
        ),
        isEmpty,
      );
    });

    test('inconsistent timing or small delays suggest nothing', () {
      final mixed = [
        taken('amlo', DateTime.utc(2026, 11, 23, 21, 30), 45),
        taken('amlo', DateTime.utc(2026, 11, 24, 21, 30), -40),
        taken('amlo', DateTime.utc(2026, 11, 25, 21, 30), 45),
      ];
      final small = [
        for (var d = 23; d <= 25; d++)
          taken('amlo', DateTime.utc(2026, 11, d, 21, 30), 10),
      ];
      expect(
        suggestMealShifts(
          logs: mixed,
          medicines: [m],
          settings: settings,
          wallNow: wallNow,
        ),
        isEmpty,
      );
      expect(
        suggestMealShifts(
          logs: small,
          medicines: [m],
          settings: settings,
          wallNow: wallNow,
        ),
        isEmpty,
      );
    });

    test('early doses suggest an earlier meal', () {
      final logs = [
        for (var d = 23; d <= 25; d++)
          taken('amlo', DateTime.utc(2026, 11, d, 21, 30), -30),
      ];
      expect(
        suggestMealShifts(
          logs: logs,
          medicines: [m],
          settings: settings,
          wallNow: wallNow,
        ).single.to,
        21 * 60,
      );
    });
  });

  group('refills', () {
    test('counts down from the last count and warns 3 days ahead', () {
      // 1+0+1 at 08:00 and 21:30; 10 counted on Nov 24 at 06:00 Dhaka. By Nov 26 10:00 five doses
      // were due (24th ×2, 25th ×2, 26th morning), leaving 5 = 2.5 days
      final m = med(
        'seclo',
        '1+0+1',
        pills: 10,
        counted: DateTime.utc(2026, 11, 24),
      );
      final r = refillStatus(m, settings, wallNow)!;
      expect(r.remaining, 5);
      expect(r.daysLeft, 2.5);
      expect(r.needsRefill, isTrue);
      expect(r.runsOutOn, DateTime.utc(2026, 11, 29));
    });

    test('no refill needed when the course ends first', () {
      final m = med(
        'napa',
        '1+1+1',
        days: 20,
        pills: 3,
        counted: DateTime.utc(2026, 11, 26, 4),
      );
      final short = Medicine(
        id: 'napa',
        name: 'napa',
        dosePattern: '1+1+1',
        durationDays: 1,
        pillsOnHand: 30,
        pillsCountedAt: DateTime.utc(2026, 11, 26, 4),
        startAt: DateTime.utc(2026, 11, 26, 4),
      );
      expect(refillStatus(short, settings, wallNow)!.needsRefill, isFalse);
      expect(refillStatus(m, settings, wallNow)!.needsRefill, isTrue);
    });

    test('unknown stock or as-needed medicines have no refill status', () {
      expect(refillStatus(med('x', '1+0+1'), settings, wallNow), isNull);
      expect(
        refillStatus(
          med('sos', '1+0+1', asNeeded: true, pills: 5, counted: wallNow),
          settings,
          wallNow,
        ),
        isNull,
      );
    });
  });

  group('adherence', () {
    test('counts taken, skipped and missed doses', () {
      final m = med('seclo', '1+0+1');
      final logs = [
        taken('seclo', DateTime.utc(2026, 11, 24, 8), 0),
        taken('seclo', DateTime.utc(2026, 11, 24, 21, 30), 5),
        DoseLog(
          medicineId: 'seclo',
          scheduledAt: DateTime.utc(2026, 11, 25, 8),
          status: DoseStatus.skipped,
          actedAt: DateTime.utc(2026, 11, 25, 2),
        ),
      ];
      final a = adherence(
        medicines: [m],
        logs: logs,
        settings: settings,
        from: DateTime.utc(2026, 11, 24),
        to: DateTime.utc(2026, 11, 26),
      );
      expect((a.scheduled, a.taken, a.skipped, a.missed), (4, 2, 1, 1));
      expect(a.rate, 0.5);
      expect(a.byMedicine['seclo'], (scheduled: 4, taken: 2));
    });
  });

  group('duplicate therapy', () {
    test('finds shared ingredients, including combinations and salts', () {
      final meds = [
        med('Napa', '1+1+1', generic: 'Paracetamol'),
        med('Napa Extra', '1+0+1', generic: 'Paracetamol + Caffeine'),
        med('Osartil', '1+0+0', generic: 'Losartan Potassium'),
        med('Angilock', '1+0+0', generic: 'Losartan'),
        med('Seclo', '1+0+1', generic: 'Omeprazole'),
      ];
      final groups = {
        for (final g in duplicateTherapies(meds))
          g.ingredient: g.medicines.map((m) => m.id).toList(),
      };
      expect(groups, {
        'paracetamol': ['Napa', 'Napa Extra'],
        'losartan': ['Osartil', 'Angilock'],
      });
    });
  });

  group('Ramadan', () {
    test(
      'meals move to sehri and iftar; daytime doses are flagged, not moved',
      () {
        final meds = [
          med('Seclo', '1+0+1', timing: Timing.beforeMeal),
          med('Napa', '1+1+1', timing: Timing.afterMeal),
          med('Amdocal', '1+0+0'),
        ];
        final plan = planRamadan(
          date: DateTime(2027, 2, 23),
          district: districtByKey('dhaka'),
          current: settings,
          medicines: meds,
        );
        expect(plan.sehriEnds, inInclusiveRange(5 * 60 + 8, 5 * 60 + 11));
        expect(plan.iftar, inInclusiveRange(17 * 60 + 57, 17 * 60 + 59));
        expect(plan.settings.breakfast, lessThanOrEqualTo(plan.sehriEnds - 30));
        // Before-meal doses (dinner − 30) must not fall before sunset
        expect(plan.settings.dinner - 30, greaterThanOrEqualTo(plan.iftar));
        expect(plan.fastingConflicts.map((m) => m.id), [
          'Napa',
        ]); // its noon dose falls in the fast
      },
    );
  });
}
