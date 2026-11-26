/// Ramadan mode: suggests meal times around sehri and iftar, and flags medicines that fall inside
/// fasting hours. Those are never moved automatically: the doctor must decide.
library;

import '../data/models.dart';
import '../schedule/schedule_engine.dart';
import '../schedule/schedule_models.dart';
import 'prayer_times.dart';

class RamadanPlan {
  const RamadanPlan({
    required this.sehriEnds,
    required this.iftar,
    required this.settings,
    required this.fastingConflicts,
  });

  /// Minutes since midnight.
  final int sehriEnds;
  final int iftar;

  /// Proposed meal times: breakfast becomes sehri, dinner becomes iftar.
  final ScheduleSettings settings;

  /// Medicines with doses during fasting hours under the proposed settings.
  final List<Medicine> fastingConflicts;
}

int _roundDown5(int m) => m - m % 5;
int _roundUp5(int m) => m % 5 == 0 ? m : m + 5 - m % 5;

/// Sehri is suggested 30 minutes before Fajr. The iftar meal is placed so that even "before meal"
/// doses fall at or after sunset, never inside the fast.
RamadanPlan planRamadan({
  required DateTime date,
  required District district,
  required ScheduleSettings current,
  required List<Medicine> medicines,
}) {
  final t = sehriIftar(date, district);
  final breakfast = _roundDown5(t.fajr - 30);
  final dinner =
      _roundUp5(t.sunset) - current.offsetBeforeMeal; // offset is negative
  // Lunch and evening stay inside the day only to keep the meal order valid; doses there conflict
  final evening = current.evening < dinner ? current.evening : dinner - 60;
  final lunch = current.lunch < evening ? current.lunch : evening - 60;
  final bedtime = current.bedtime > dinner ? current.bedtime : dinner + 90;
  final settings = ScheduleSettings(
    breakfast: breakfast,
    lunch: lunch,
    evening: evening,
    dinner: dinner,
    bedtime: bedtime,
    offsetBeforeMeal: current.offsetBeforeMeal,
    offsetAfterMeal: current.offsetAfterMeal,
    offsetEmptyStomach: current.offsetEmptyStomach,
    groupWindowMinutes: current.groupWindowMinutes,
  );

  final conflicts = <Medicine>[];
  for (final m in medicines.where((m) => !m.asNeeded)) {
    final times = dailyTimes(m.toScheduleInput(), settings);
    // Fasting from Fajr to sunset
    if (times.any(
      (d) =>
          d.minutes % minutesPerDay >= t.fajr &&
          d.minutes % minutesPerDay < t.sunset,
    )) {
      conflicts.add(m);
    }
  }
  return RamadanPlan(
    sehriEnds: t.fajr,
    iftar: t.sunset,
    settings: settings,
    fastingConflicts: conflicts,
  );
}
