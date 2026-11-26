/// Schedule engine models. Mirrors `backend/app/schedule/models.py`.
///
/// All [DateTime] values are **wall-clock** times stored as UTC instances, so arithmetic is free of
/// daylight-saving jumps regardless of the device's time zone. Convert to real instants only when
/// handing alarms to the OS.
library;

const minutesPerDay = 24 * 60;

enum Slot { morning, noon, evening, night, interval }

enum Timing {
  beforeMeal,
  afterMeal,
  withMeal,
  emptyStomach,
  bedtime,
  notSpecified,
}

Timing timingFromJson(String value) => switch (value) {
  'before_meal' => Timing.beforeMeal,
  'after_meal' => Timing.afterMeal,
  'with_meal' => Timing.withMeal,
  'empty_stomach' => Timing.emptyStomach,
  'bedtime' => Timing.bedtime,
  'not_specified' => Timing.notSpecified,
  _ => throw ArgumentError.value(value, 'timing'),
};

/// Minutes since midnight.
typedef ClockMinutes = int;

ClockMinutes parseClock(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

class ScheduleSettings {
  const ScheduleSettings({
    this.breakfast = 8 * 60,
    this.lunch = 13 * 60 + 30,
    this.evening = 17 * 60 + 30,
    this.dinner = 21 * 60 + 30,
    this.bedtime = 22 * 60 + 30,
    this.offsetBeforeMeal = -30,
    this.offsetAfterMeal = 15,
    this.offsetEmptyStomach = -60,
    this.groupWindowMinutes = 10,
  });

  final ClockMinutes breakfast;
  final ClockMinutes lunch;
  final ClockMinutes evening;
  final ClockMinutes dinner;
  final ClockMinutes bedtime;
  final int offsetBeforeMeal;
  final int offsetAfterMeal;
  final int offsetEmptyStomach;
  final int groupWindowMinutes;
}

class MedicineInput {
  const MedicineInput({
    required this.id,
    required this.start,
    this.dosePattern,
    this.intervalHours,
    this.intervalAmount = '1',
    this.timing = Timing.notSpecified,
    this.durationDays,
    this.weekdays,
    this.asNeeded = false,
  });

  final String id;
  final String? dosePattern;
  final int? intervalHours;
  final String intervalAmount;
  final Timing timing;

  /// Null means continue indefinitely.
  final int? durationDays;

  /// ISO weekdays (1 = Monday) for weekly medicines.
  final List<int>? weekdays;
  final bool asNeeded;

  /// Wall-clock start (see library docs).
  final DateTime start;
}

class DoseTime {
  const DoseTime(this.slot, this.minutes, this.amount);

  final Slot slot;

  /// Minutes from the start of the schedule day; may exceed [minutesPerDay].
  final int minutes;
  final String amount;

  int get dayOffset => minutes ~/ minutesPerDay;

  String get clock {
    final m = minutes % minutesPerDay;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }
}

class MedicineSchedule {
  const MedicineSchedule({
    required this.medicineId,
    required this.dosesPerDay,
    required this.dailyTimes,
    required this.totalDoses,
    required this.firstDoseAt,
    required this.lastDoseAt,
  });

  final String medicineId;
  final int dosesPerDay;
  final List<DoseTime> dailyTimes;
  final int? totalDoses;
  final DateTime? firstDoseAt;
  final DateTime? lastDoseAt;
}

class Occurrence {
  const Occurrence(this.at, this.medicineId, this.amount, this.slot);

  final DateTime at;
  final String medicineId;
  final String amount;
  final Slot slot;
}

class Reminder {
  Reminder(this.at, this.items);

  final DateTime at;
  final List<Occurrence> items;
}

/// Invalid input; [code] is one of the error codes in docs/SCHEDULE_SPEC.md §6.
class ScheduleException implements Exception {
  const ScheduleException(this.code, this.message, [this.medicineId]);

  final String code;
  final String message;
  final String? medicineId;

  @override
  String toString() => 'ScheduleException($code): $message';
}
