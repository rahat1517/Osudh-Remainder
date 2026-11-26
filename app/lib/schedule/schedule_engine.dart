/// Schedule engine (docs/SCHEDULE_SPEC.md). Mirrors `backend/app/schedule/engine.py`.
///
/// Pure functions, no I/O. Checked against spec/schedule/vectors.json by
/// test/schedule_conformance_test.dart.
library;

import 'dose_pattern.dart';
import 'schedule_models.dart';

const maxDurationDays = 365;
const validIntervals = {1, 2, 3, 4, 6, 8, 12, 24};

const _slotsByParts = {
  2: [Slot.morning, Slot.night],
  3: [Slot.morning, Slot.noon, Slot.night],
  4: [Slot.morning, Slot.noon, Slot.evening, Slot.night],
};

class _Plan {
  _Plan(this.medicine, this.times, this.total, this.weeklyEnd);

  final MedicineInput medicine;
  final List<DoseTime> times;
  final int? total;
  final DateTime? weeklyEnd; // exclusive, midnight
}

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

// ---------------------------------------------------------------------------
// Validation and daily times (spec §2, §3.1–3.5)
// ---------------------------------------------------------------------------
void validateSettings(ScheduleSettings s) {
  final meals = [s.breakfast, s.lunch, s.evening, s.dinner];
  for (var i = 0; i < meals.length - 1; i++) {
    if (meals[i] >= meals[i + 1]) {
      throw const ScheduleException(
        'invalid_meal_times',
        'Meal times must be in order: breakfast < lunch < evening < dinner',
      );
    }
  }
}

int _mealMinutes(Slot slot, ScheduleSettings s) => switch (slot) {
  Slot.morning => s.breakfast,
  Slot.noon => s.lunch,
  Slot.evening => s.evening,
  Slot.night => s.dinner,
  Slot.interval => s.breakfast,
};

int _bedtimeMinutes(ScheduleSettings s) =>
    s.bedtime < s.breakfast ? s.bedtime + minutesPerDay : s.bedtime;

int _offset(Timing timing, ScheduleSettings s) => switch (timing) {
  Timing.beforeMeal => s.offsetBeforeMeal,
  Timing.afterMeal => s.offsetAfterMeal,
  Timing.emptyStomach => s.offsetEmptyStomach,
  _ => 0,
};

/// Dose times within one schedule day, ordered by time.
List<DoseTime> dailyTimes(MedicineInput med, ScheduleSettings s) {
  if (med.asNeeded) return const [];
  final interval = med.intervalHours;
  if (interval != null) {
    return [
      for (var i = 0; i < 24 ~/ interval; i++)
        DoseTime(
          Slot.interval,
          s.breakfast + i * interval * 60,
          med.intervalAmount,
        ),
    ];
  }
  final amounts = parseDosePattern(med.dosePattern)!;
  final slots = _slotsByParts[amounts.length]!;
  final times = <DoseTime>[];
  for (var i = 0; i < amounts.length; i++) {
    if (amounts[i] == 0) continue;
    final slot = slots[i];
    final minutes = med.timing == Timing.bedtime && slot == Slot.night
        ? _bedtimeMinutes(s)
        : _mealMinutes(slot, s) + _offset(med.timing, s);
    times.add(DoseTime(slot, minutes, formatAmount(amounts[i])));
  }
  times.sort((a, b) => a.minutes.compareTo(b.minutes));
  return times;
}

_Plan _plan(MedicineInput med, ScheduleSettings s) {
  Never fail(String code, String message) =>
      throw ScheduleException(code, message, med.id);

  if (med.dosePattern != null && med.intervalHours != null) {
    fail(
      'conflicting_dose',
      'Give either dose_pattern or interval_hours, not both',
    );
  }
  if (!med.asNeeded) {
    if (med.dosePattern == null && med.intervalHours == null) {
      fail('missing_dose', 'A dose_pattern or interval_hours is required');
    }
    if (med.dosePattern != null && parseDosePattern(med.dosePattern) == null) {
      fail(
        'invalid_dose_pattern',
        "Cannot use dose pattern '${med.dosePattern}'",
      );
    }
    if (med.intervalHours != null &&
        !validIntervals.contains(med.intervalHours)) {
      fail('invalid_interval', 'interval_hours must divide 24');
    }
  }
  final days = med.durationDays;
  if (days != null && (days < 1 || days > maxDurationDays)) {
    fail(
      'invalid_duration',
      'duration_days must be between 1 and $maxDurationDays',
    );
  }
  final weekdays = med.weekdays;
  if (weekdays != null &&
      (weekdays.isEmpty || weekdays.any((d) => d < 1 || d > 7))) {
    fail(
      'invalid_weekdays',
      'weekdays must be a non-empty list of ISO weekdays 1-7',
    );
  }

  final times = dailyTimes(med, s);
  int? total;
  DateTime? weeklyEnd;
  if (days != null && times.isNotEmpty) {
    if (weekdays != null && weekdays.isNotEmpty) {
      weeklyEnd = _dateOnly(med.start).add(Duration(days: days));
    } else {
      total = days * times.length;
    }
  }
  return _Plan(med, times, total, weeklyEnd);
}

// ---------------------------------------------------------------------------
// Occurrences (spec §3.6, §3.7)
// ---------------------------------------------------------------------------
Iterable<Occurrence> _occurrences(_Plan plan) sync* {
  final med = plan.medicine;
  final times = plan.times;
  if (times.isEmpty) return;
  final start = med.start;
  final earliest = times.first.minutes;
  final weekdays = med.weekdays?.toSet() ?? const <int>{};

  // Kept sorted by time; holds candidates that might still be preceded by a later day's dose.
  final pending = <Occurrence>[];
  var emitted = 0;
  var day = _dateOnly(start).subtract(const Duration(days: 1));
  final lastDay = _dateOnly(start)
      .add(const Duration(days: maxDurationDays + 2));

  while (true) {
    final threshold = day.add(Duration(minutes: earliest));
    while (pending.isNotEmpty && pending.first.at.isBefore(threshold)) {
      yield pending.removeAt(0);
      emitted++;
      if (plan.total != null && emitted == plan.total) return;
    }
    final done =
        (plan.weeklyEnd != null && !day.isBefore(plan.weeklyEnd!)) ||
        (plan.total != null && day.isAfter(lastDay));
    if (done) {
      yield* pending;
      return;
    }

    if (weekdays.isEmpty || weekdays.contains(day.weekday)) {
      for (final t in times) {
        final at = day.add(Duration(minutes: t.minutes));
        if (at.isBefore(start)) continue;
        if (plan.weeklyEnd != null && !at.isBefore(plan.weeklyEnd!)) continue;
        final occ = Occurrence(at, med.id, t.amount, t.slot);
        final index = pending.indexWhere((p) => p.at.isAfter(at));
        pending.insert(index < 0 ? pending.length : index, occ);
      }
    }
    day = day.add(const Duration(days: 1));
  }
}

MedicineSchedule _summary(_Plan plan) {
  final finite = plan.total != null || plan.weeklyEnd != null;
  final iterator = _occurrences(plan).iterator;
  DateTime? first;
  DateTime? last;
  var total = plan.total;
  if (iterator.moveNext()) {
    first = iterator.current.at;
    if (finite) {
      var n = 1;
      last = first;
      while (iterator.moveNext()) {
        n++;
        last = iterator.current.at;
      }
      total = n;
    }
  } else if (finite) {
    total = 0;
  }
  return MedicineSchedule(
    medicineId: plan.medicine.id,
    dosesPerDay: plan.times.length,
    dailyTimes: plan.times,
    totalDoses: total,
    firstDoseAt: first,
    lastDoseAt: last,
  );
}

int _compareOccurrences(Occurrence a, Occurrence b) {
  final byTime = a.at.compareTo(b.at);
  return byTime != 0 ? byTime : a.medicineId.compareTo(b.medicineId);
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------
MedicineSchedule scheduleMedicine(
  MedicineInput med,
  ScheduleSettings settings,
) {
  validateSettings(settings);
  return _summary(_plan(med, settings));
}

/// Occurrences of all [medicines] in `[windowStart, windowEnd)`, ordered by time then id.
List<Occurrence> occurrencesBetween(
  List<MedicineInput> medicines,
  ScheduleSettings settings,
  DateTime windowStart,
  DateTime windowEnd,
) {
  validateSettings(settings);
  final result = <Occurrence>[];
  for (final med in medicines) {
    for (final occ in _occurrences(_plan(med, settings))) {
      if (!occ.at.isBefore(windowEnd)) break;
      if (!occ.at.isBefore(windowStart)) result.add(occ);
    }
  }
  result.sort(_compareOccurrences);
  return result;
}

/// Groups occurrences into reminders (spec §5): never later, at most [windowMinutes] earlier.
List<Reminder> groupReminders(List<Occurrence> occurrences, int windowMinutes) {
  final sorted = [...occurrences]..sort(_compareOccurrences);
  final window = Duration(minutes: windowMinutes);
  final reminders = <Reminder>[];
  for (final occ in sorted) {
    if (reminders.isNotEmpty &&
        occ.at.difference(reminders.last.at) <= window) {
      reminders.last.items.add(occ);
    } else {
      reminders.add(Reminder(occ.at, [occ]));
    }
  }
  return reminders;
}
