import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/models.dart';

import 'helpers.dart';

void main() {
  final scan = PrescriptionScan.fromJson(exampleScanJson());

  test('a fully certain scanned medicine is ready', () {
    final d = MedicineDraft.fromScan(scan.medicines[0]);
    expect(d.isReady, isTrue);
    expect(d.toRow(prescriptionId: 'p')['dose_pattern'], '1+0+1');
    expect(d.toRow(prescriptionId: 'p')['timing'], 'before_meal');
  });

  test('a medium-confidence field blocks confirmation until reviewed', () {
    final d = MedicineDraft.fromScan(scan.medicines[1]);
    expect(d.problems, [DraftProblem.needsReview]);
    d.name.markReviewed();
    expect(d.isReady, isTrue);
  });

  test('editing a field counts as reviewing it', () {
    final d = MedicineDraft.fromScan(scan.medicines[1]);
    d.name.edit('Sergel');
    expect(d.isReady, isTrue);
  });

  test('as-needed medicines need no dose or duration, and hidden fields need no review', () {
    final d = MedicineDraft.fromScan(scan.medicines[2]);
    // The strength was suggested from the catalogue (medium), so it must be checked;
    // the hidden duration (medium) must not block confirmation.
    expect(d.problems, [DraftProblem.needsReview]);
    d.strength.markReviewed();
    expect(d.isReady, isTrue);
    final row = d.toRow(prescriptionId: 'p');
    expect(row['as_needed'], isTrue);
    expect(row['dose_pattern'], isNull);
  });

  test('manual entry validates name, dose and duration', () {
    final d = MedicineDraft.manual();
    expect(
      d.problems,
      containsAll([
        DraftProblem.nameRequired,
        DraftProblem.doseInvalid,
        DraftProblem.durationRequired,
      ]),
    );
    d.name.edit('Napa');
    d.dose.edit('১+১+১');
    d.durationDays.edit(5);
    expect(d.isReady, isTrue);
    expect(d.toRow(prescriptionId: 'p')['dose_pattern'], '1+1+1');
  });

  test('continue indefinitely replaces the duration', () {
    final d = MedicineDraft.manual()
      ..name.edit('Amdocal')
      ..dose.edit('1+0+0')
      ..continueIndefinitely = true;
    expect(d.isReady, isTrue);
    expect(d.toRow(prescriptionId: 'p')['duration_days'], isNull);
  });

  test('selecting a catalogue drug fills name, strength and form', () {
    final d = MedicineDraft.manual()
      ..selectDrug(
        const Drug(
          id: 7,
          brand: 'Maxpro',
          strength: '20 mg',
          generic: 'Esomeprazole',
          form: 'Tablet',
        ),
      );
    expect(d.name.value, 'Maxpro');
    expect(d.strength.value, '20 mg');
    expect(d.toRow(prescriptionId: 'p')['drug_id'], 7);
  });
}
