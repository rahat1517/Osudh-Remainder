/// Insights computed on the phone from the medicine list and the dose log. Pure functions.
library;

import '../alarms/dose_log.dart';
import '../data/models.dart';
import '../schedule/schedule_engine.dart';
import '../schedule/schedule_models.dart';

// ---------------------------------------------------------------------------
// Learning actual dose times
// ---------------------------------------------------------------------------

/// A suggestion to move a meal time because doses are consistently taken earlier or later.
class MealShift {
  const MealShift(this.meal, this.from, this.to, this.days);

  final String meal; // breakfast, lunch, evening, dinner, bedtime
  final int from; // minutes since midnight
  final int to;
  final int days; // days of evidence
}

/// Minimum consistent shift worth suggesting, and evidence needed.
const minShiftMinutes = 20;
const minShiftDays = 3;

String _mealFor(Slot slot, Timing timing) => switch (slot) {
  Slot.morning => 'breakfast',
  Slot.noon => 'lunch',
  Slot.evening => 'evening',
  Slot.night => timing == Timing.bedtime ? 'bedtime' : 'dinner',
  Slot.interval => '',
};

int _mealMinutes(String meal, ScheduleSettings s) => switch (meal) {
  'breakfast' => s.breakfast,
  'lunch' => s.lunch,
  'evening' => s.evening,
  'dinner' => s.dinner,
  _ => s.bedtime,
};

/// Looks at "taken" doses in the last 7 days. If, for a meal, doses on at least 3 different days
/// were all taken at least 20 minutes late (or all early), suggests moving that meal by the median.
List<MealShift> suggestMealShifts({
  required List<DoseLog> logs,
  required List<Medicine> medicines,
  required ScheduleSettings settings,
  required DateTime wallNow,
  Duration utcOffset = const Duration(hours: 6),
}) {
  final byId = {for (final m in medicines) m.id: m};
  final since = wallNow.subtract(const Duration(days: 7));
  // meal → day → delays (minutes)
  final delays = <String, Map<DateTime, List<int>>>{};
  for (final log in logs) {
    final med = byId[log.medicineId];
    if (med == null ||
        log.status != DoseStatus.taken ||
        log.scheduledAt.isBefore(since)) {
      continue;
    }
    final clock = log.scheduledAt.hour * 60 + log.scheduledAt.minute;
    final slot = dailyTimes(med.toScheduleInput(utcOffset: utcOffset), settings)
        .where((t) => t.minutes % minutesPerDay == clock)
        .map((t) => t.slot)
        .firstOrNull;
    if (slot == null || slot == Slot.interval) continue;
    final acted = log.actedAt.toUtc().add(utcOffset);
    final actedWall = DateTime.utc(
      acted.year,
      acted.month,
      acted.day,
      acted.hour,
      acted.minute,
    );
    final day = DateTime.utc(
      log.scheduledAt.year,
      log.scheduledAt.month,
      log.scheduledAt.day,
    );
    delays
        .putIfAbsent(_mealFor(slot, med.timing), () => {})
        .putIfAbsent(day, () => [])
        .add(actedWall.difference(log.scheduledAt).inMinutes);
  }

  final shifts = <MealShift>[];
  delays.forEach((meal, perDay) {
    if (perDay.length < minShiftDays) return;
    final daily = [for (final d in perDay.values) (d..sort())[d.length ~/ 2]]
      ..sort();
    final late = daily.every((d) => d >= minShiftMinutes);
    final early = daily.every((d) => d <= -minShiftMinutes);
    if (!late && !early) return;
    final median = daily[daily.length ~/ 2];
    final from = _mealMinutes(meal, settings);
    final to = ((from + median) / 5).round() * 5;
    shifts.add(MealShift(meal, from, to, perDay.length));
  });
  return shifts;
}

// ---------------------------------------------------------------------------
// Refills
// ---------------------------------------------------------------------------

class RefillStatus {
  const RefillStatus({
    required this.remaining,
    required this.daysLeft,
    required this.runsOutOn,
    required this.needsRefill,
  });

  final double remaining;
  final double daysLeft;
  final DateTime? runsOutOn; // wall-clock date, null if the course ends first
  final bool needsRefill;
}

const refillWarningDays = 3;

/// Tablets left from the last count, minus the doses scheduled since then.
RefillStatus? refillStatus(
  Medicine m,
  ScheduleSettings settings,
  DateTime wallNow, {
  Duration utcOffset = const Duration(hours: 6),
}) {
  final stock = m.pillsOnHand;
  final countedAt = m.pillsCountedAt;
  if (stock == null || countedAt == null || m.asNeeded) return null;
  final counted = countedAt.toUtc().add(utcOffset);
  final countedWall = DateTime.utc(
    counted.year,
    counted.month,
    counted.day,
    counted.hour,
    counted.minute,
  );
  final input = m.toScheduleInput(utcOffset: utcOffset);
  final used = occurrencesBetween(
    [input],
    settings,
    countedWall,
    wallNow,
  ).fold<double>(0, (s, o) => s + double.parse(o.amount));
  final remaining = (stock - used).clamp(0, double.infinity).toDouble();
  final perDay = dailyTimes(
    input,
    settings,
  ).fold<double>(0, (s, t) => s + double.parse(t.amount));
  if (perDay == 0) return null;

  // Doses still to come in the course (all, capped at a year, for indefinite courses)
  final upcoming = occurrencesBetween(
    [input],
    settings,
    wallNow,
    wallNow.add(const Duration(days: 366)),
  );
  var left = remaining;
  DateTime? runsOut;
  for (final o in upcoming) {
    left -= double.parse(o.amount);
    if (left < 0) {
      runsOut = DateTime.utc(o.at.year, o.at.month, o.at.day);
      break;
    }
  }
  final daysLeft = remaining / perDay;
  return RefillStatus(
    remaining: remaining,
    daysLeft: daysLeft,
    runsOutOn: runsOut,
    needsRefill: runsOut != null && daysLeft <= refillWarningDays,
  );
}

// ---------------------------------------------------------------------------
// Adherence
// ---------------------------------------------------------------------------

class Adherence {
  const Adherence(this.scheduled, this.taken, this.skipped, this.byMedicine);

  final int scheduled;
  final int taken;
  final int skipped;
  final Map<String, ({int scheduled, int taken})> byMedicine;

  int get missed => scheduled - taken - skipped;
  double get rate => scheduled == 0 ? 1 : taken / scheduled;
}

/// Doses due in [from, to) (only those at least 30 minutes past) and what happened to them.
Adherence adherence({
  required List<Medicine> medicines,
  required List<DoseLog> logs,
  required ScheduleSettings settings,
  required DateTime from,
  required DateTime to,
  Duration utcOffset = const Duration(hours: 6),
}) {
  final status = {for (final l in logs) l.key: l.status};
  final occ = occurrencesBetween(
    [for (final m in medicines) m.toScheduleInput(utcOffset: utcOffset)],
    settings,
    from,
    to,
  );
  var taken = 0, skipped = 0;
  final per = <String, ({int scheduled, int taken})>{};
  for (final o in occ) {
    final s = status[doseKey(o.medicineId, o.at)];
    if (s == DoseStatus.taken) taken++;
    if (s == DoseStatus.skipped) skipped++;
    final prev = per[o.medicineId] ?? (scheduled: 0, taken: 0);
    per[o.medicineId] = (
      scheduled: prev.scheduled + 1,
      taken: prev.taken + (s == DoseStatus.taken ? 1 : 0),
    );
  }
  return Adherence(occ.length, taken, skipped, per);
}

// ---------------------------------------------------------------------------
// Duplicate therapy
// ---------------------------------------------------------------------------

const _saltWords = {
  'hydrochloride',
  'hcl',
  'sodium',
  'potassium',
  'calcium',
  'magnesium',
  'tromethamine',
  'maleate',
  'besylate',
  'mesylate',
  'citrate',
  'sulfate',
  'sulphate',
};

Set<String> genericComponents(String generic) => {
  for (final part in generic.toLowerCase().split(
    RegExp(r'\s*\+\s*|\s*,\s*|\s+and\s+'),
  ))
    if (part.trim().isNotEmpty)
      part
          .split(RegExp(r'\s+'))
          .where((w) => !_saltWords.contains(w))
          .join(' ')
          .trim(),
}..remove('');

/// Groups of active medicines that share an active ingredient (e.g. Napa and Ace: paracetamol).
List<({String ingredient, List<Medicine> medicines})> duplicateTherapies(
  List<Medicine> medicines,
) {
  final byIngredient = <String, List<Medicine>>{};
  for (final m in medicines) {
    final generic = m.generic;
    if (generic == null || generic.isEmpty) continue;
    for (final c in genericComponents(generic)) {
      byIngredient.putIfAbsent(c, () => []).add(m);
    }
  }
  return [
    for (final e in byIngredient.entries)
      if (e.value.length > 1) (ingredient: e.key, medicines: e.value),
  ];
}
