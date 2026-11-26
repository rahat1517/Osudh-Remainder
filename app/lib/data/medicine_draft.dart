/// Editable medicine on the confirm screen.
///
/// Safety rule: a field the AI was not sure about (medium or low confidence) must be reviewed by
/// the user, by confirming or editing it, before the prescription can be confirmed.
library;

import '../schedule/dose_pattern.dart';
import '../schedule/schedule_models.dart';
import 'models.dart';

class DraftField<T> {
  DraftField(this.value, {this.confidence = Confidence.high, this.note})
    : reviewed = confidence == Confidence.high;

  T? value;
  final Confidence confidence;
  final Notice? note;
  bool reviewed;

  bool get needsReview => !reviewed;

  void edit(T? newValue) {
    value = newValue;
    reviewed = true;
  }

  void markReviewed() => reviewed = true;
}

/// Why a draft cannot be saved yet (localized by the UI).
enum DraftProblem { nameRequired, doseInvalid, durationRequired, needsReview }

class MedicineDraft {
  MedicineDraft({
    required this.name,
    required this.strength,
    required this.dose,
    required this.timing,
    required this.durationDays,
    this.drugId,
    this.form,
    this.generic,
    this.alternatives = const [],
    this.continueIndefinitely = false,
    this.asNeeded = false,
    this.rawText,
  });

  factory MedicineDraft.fromScan(ScannedMedicine m) => MedicineDraft(
    rawText: m.rawText,
    name: DraftField(
      m.name.value,
      confidence: m.name.confidence,
      note: m.name.note,
    ),
    drugId: m.drug?.id,
    form: m.drug?.form,
    generic: m.drug?.generic,
    alternatives: m.alternatives,
    strength: DraftField(
      m.strength.value,
      confidence: m.strength.confidence,
      note: m.strength.note,
    ),
    dose: DraftField(
      m.dose.value,
      confidence: m.dose.confidence,
      note: m.dose.note,
    ),
    timing: DraftField(
      m.timing.value ?? Timing.notSpecified,
      confidence: m.timing.confidence,
      note: m.timing.note,
    ),
    durationDays: DraftField(
      m.duration.value,
      confidence: m.duration.confidence,
      note: m.duration.note,
    ),
    continueIndefinitely: m.continueIndefinitely,
    asNeeded: m.asNeeded,
  );

  /// A blank medicine typed in by the user (everything counts as user-provided).
  factory MedicineDraft.manual() => MedicineDraft(
    name: DraftField<String>(null),
    strength: DraftField<String>(null),
    dose: DraftField<String>(null),
    timing: DraftField<Timing>(Timing.notSpecified),
    durationDays: DraftField<int>(null),
  );

  final DraftField<String> name;
  final DraftField<String> strength;
  final DraftField<String> dose;
  final DraftField<Timing> timing;
  final DraftField<int> durationDays;
  int? drugId;
  String? form;
  String? generic;
  final List<Drug> alternatives;
  bool continueIndefinitely;
  bool asNeeded;
  final String? rawText;

  Iterable<DraftField<Object?>> get fields => [
    name,
    strength,
    dose,
    timing,
    durationDays,
  ];

  /// Fields the user can see and must review. Dose, timing and duration are hidden for
  /// as-needed medicines, so they cannot block confirmation.
  Iterable<DraftField<Object?>> get visibleFields =>
      asNeeded ? [name, strength] : fields;

  void selectDrug(Drug drug) {
    name.edit(drug.brand);
    if (drug.strength.isNotEmpty) strength.edit(drug.strength);
    drugId = drug.id;
    form = drug.form;
    generic = drug.generic;
  }

  List<DraftProblem> get problems => [
    if ((name.value ?? '').trim().isEmpty) DraftProblem.nameRequired,
    if (!asNeeded && parseDosePattern(dose.value) == null)
      DraftProblem.doseInvalid,
    if (!asNeeded && !continueIndefinitely && !_validDays)
      DraftProblem.durationRequired,
    if (visibleFields.any((f) => f.needsReview)) DraftProblem.needsReview,
  ];

  bool get _validDays {
    final d = durationDays.value;
    return d != null && d >= 1 && d <= 365;
  }

  bool get isReady => problems.isEmpty;

  /// Confirmed values as a training label (no free text, so no personal data).
  Map<String, dynamic> toTrainingLabel() => {
    'name': name.value!.trim(),
    'strength': _blankToNull(strength.value),
    'dose_pattern': asNeeded && parseDosePattern(dose.value) == null
        ? null
        : normalizeDosePattern(dose.value),
    'timing': timingJson[timing.value ?? Timing.notSpecified],
    'duration_days': continueIndefinitely ? null : durationDays.value,
    'continue_indefinitely': continueIndefinitely,
    'as_needed': asNeeded,
  };

  /// Row for the `medicines` table.
  Map<String, dynamic> toRow({
    required String prescriptionId,
    String? forUserId,
  }) => {
    'prescription_id': prescriptionId,
    'user_id': ?forUserId,
    'name': name.value!.trim(),
    'strength': _blankToNull(strength.value),
    'form': form,
    'drug_id': drugId,
    'generic': generic,
    'dose_pattern': asNeeded && parseDosePattern(dose.value) == null
        ? null
        : normalizeDosePattern(dose.value),
    'timing': timingJson[timing.value ?? Timing.notSpecified],
    'duration_days': continueIndefinitely ? null : durationDays.value,
    'as_needed': asNeeded,
    'raw_text': rawText,
  };
}

String? _blankToNull(String? s) =>
    s == null || s.trim().isEmpty ? null : s.trim();
