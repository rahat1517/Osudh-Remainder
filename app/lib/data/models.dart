/// App-side models. JSON shapes follow the backend API (backend/README.md).
library;

import '../schedule/schedule_models.dart';

enum Confidence { high, medium, low }

Confidence confidenceFromJson(String v) => Confidence.values.byName(v);

const timingJson = {
  Timing.beforeMeal: 'before_meal',
  Timing.afterMeal: 'after_meal',
  Timing.withMeal: 'with_meal',
  Timing.emptyStomach: 'empty_stomach',
  Timing.bedtime: 'bedtime',
  Timing.notSpecified: 'not_specified',
};

/// A machine-readable message from the backend; the app localizes [code].
class Notice {
  const Notice(this.code, [this.params = const {}]);

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
    j['code'] as String,
    (j['params'] as Map?)?.cast<String, String>() ?? const {},
  );

  final String code;
  final Map<String, String> params;
}

class FieldValue<T> {
  const FieldValue(this.value, this.confidence, [this.note]);

  final T? value;
  final Confidence confidence;
  final Notice? note;
}

FieldValue<T> _field<T>(
  Map<String, dynamic> j,
  T? Function(Object? raw) parse,
) => FieldValue<T>(
  parse(j['value']),
  confidenceFromJson(j['confidence'] as String),
  j['note'] == null ? null : Notice.fromJson(j['note'] as Map<String, dynamic>),
);

class Drug {
  const Drug({
    required this.id,
    required this.brand,
    required this.strength,
    required this.generic,
    required this.form,
  });

  factory Drug.fromJson(Map<String, dynamic> j) => Drug(
    id: j['id'] as int,
    brand: j['brand'] as String,
    strength: j['strength'] as String? ?? '',
    generic: j['generic'] as String,
    form: j['form'] as String,
  );

  final int id;
  final String brand;
  final String strength;
  final String generic;
  final String form;

  String get label => strength.isEmpty ? brand : '$brand $strength';
}

/// One medicine as read from a prescription, after server-side verification.
class ScannedMedicine {
  const ScannedMedicine({
    required this.rawText,
    required this.name,
    required this.drug,
    required this.alternatives,
    required this.strength,
    required this.dose,
    required this.timing,
    required this.duration,
    required this.asNeeded,
    this.continueIndefinitely = false,
  });

  factory ScannedMedicine.fromJson(Map<String, dynamic> j) {
    final duration = j['duration'] as Map<String, dynamic>;
    final dv = duration['value'] as Map<String, dynamic>?;
    return ScannedMedicine(
      rawText: j['raw_text'] as String,
      name: _field<String>(
        j['name'] as Map<String, dynamic>,
        (v) => v as String?,
      ),
      drug: j['matched_drug'] == null
          ? null
          : Drug.fromJson(
              (j['matched_drug'] as Map)['drug'] as Map<String, dynamic>,
            ),
      alternatives: [
        for (final c in j['alternatives'] as List)
          Drug.fromJson((c as Map)['drug'] as Map<String, dynamic>),
      ],
      strength: _field<String>(
        j['strength'] as Map<String, dynamic>,
        (v) => v as String?,
      ),
      dose: _field<String>(
        j['dose'] as Map<String, dynamic>,
        (v) => v as String?,
      ),
      timing: _field<Timing>(
        j['timing'] as Map<String, dynamic>,
        (v) => v == null ? null : timingFromJson(v as String),
      ),
      duration: FieldValue<int>(
        dv?['days'] as int?,
        confidenceFromJson(duration['confidence'] as String),
        duration['note'] == null
            ? null
            : Notice.fromJson(duration['note'] as Map<String, dynamic>),
      ),
      asNeeded: j['as_needed'] as bool,
      continueIndefinitely: dv?['continue_indefinitely'] as bool? ?? false,
    );
  }

  final String rawText;
  final FieldValue<String> name;
  final Drug? drug;
  final List<Drug> alternatives;
  final FieldValue<String> strength;
  final FieldValue<String> dose;
  final FieldValue<Timing> timing;
  final FieldValue<int> duration;
  final bool asNeeded;
  final bool continueIndefinitely;
}

class PrescriptionScan {
  const PrescriptionScan({
    required this.imageQuality,
    required this.medicines,
    required this.warnings,
  });

  factory PrescriptionScan.fromJson(Map<String, dynamic> j) => PrescriptionScan(
    imageQuality: j['image_quality'] as String,
    medicines: [
      for (final m in j['medicines'] as List)
        ScannedMedicine.fromJson(m as Map<String, dynamic>),
    ],
    warnings: [
      for (final w in j['warnings'] as List)
        Notice.fromJson(w as Map<String, dynamic>),
    ],
  );

  final String imageQuality;
  final List<ScannedMedicine> medicines;
  final List<Notice> warnings;
}

/// A medicine the user has confirmed; the input to the schedule engine.
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.startAt,
    this.strength,
    this.form,
    this.drugId,
    this.dosePattern,
    this.intervalHours,
    this.timing = Timing.notSpecified,
    this.durationDays,
    this.weekdays,
    this.asNeeded = false,
  });

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
    id: j['id'] as String,
    name: j['name'] as String,
    strength: j['strength'] as String?,
    form: j['form'] as String?,
    drugId: j['drug_id'] as int?,
    dosePattern: j['dose_pattern'] as String?,
    intervalHours: j['interval_hours'] as int?,
    timing: timingFromJson(j['timing'] as String),
    durationDays: j['duration_days'] as int?,
    weekdays: (j['weekdays'] as List?)?.cast<int>(),
    asNeeded: j['as_needed'] as bool? ?? false,
    startAt: DateTime.parse(j['start_at'] as String),
  );

  final String id;
  final String name;
  final String? strength;
  final String? form;
  final int? drugId;
  final String? dosePattern;
  final int? intervalHours;
  final Timing timing;
  final int? durationDays;
  final List<int>? weekdays;
  final bool asNeeded;

  /// Real instant the course started.
  final DateTime startAt;

  String get label =>
      strength == null || strength!.isEmpty ? name : '$name $strength';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'strength': strength,
    'form': form,
    'drug_id': drugId,
    'dose_pattern': dosePattern,
    'interval_hours': intervalHours,
    'timing': timingJson[timing],
    'duration_days': durationDays,
    'weekdays': weekdays,
    'as_needed': asNeeded,
    'start_at': startAt.toUtc().toIso8601String(),
  };

  /// Input for the schedule engine, with [startAt] converted to wall-clock time in a fixed-offset
  /// zone (Asia/Dhaka is UTC+6 with no daylight saving).
  MedicineInput toScheduleInput({
    Duration utcOffset = const Duration(hours: 6),
  }) {
    final local = startAt.toUtc().add(utcOffset);
    return MedicineInput(
      id: id,
      start: DateTime.utc(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
      ),
      dosePattern: dosePattern,
      intervalHours: intervalHours,
      timing: timing,
      durationDays: durationDays,
      weekdays: weekdays,
      asNeeded: asNeeded,
    );
  }
}
