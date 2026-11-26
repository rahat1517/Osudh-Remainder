import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';

import 'helpers.dart';

void main() {
  test('parses the backend contract example', () {
    final scan = PrescriptionScan.fromJson(exampleScanJson());
    expect(scan.imageQuality, 'readable_with_effort');
    expect(scan.medicines, hasLength(3));

    final seclo = scan.medicines[0];
    expect(seclo.name.value, 'Seclo');
    expect(seclo.name.confidence, Confidence.high);
    expect(seclo.dose.value, '1+0+1');
    expect(seclo.timing.value, Timing.beforeMeal);
    expect(seclo.duration.value, 30);
    expect(seclo.drug?.brand, 'Seclo');

    final sergel = scan.medicines[1];
    expect(sergel.name.confidence, Confidence.medium);
    expect(sergel.name.note?.code, 'name_corrected');
    expect(sergel.name.note?.params['written'], 'Sargel');

    expect(scan.medicines[2].asNeeded, isTrue);
    expect(
      scan.warnings.map((w) => w.code),
      contains('review_highlighted_fields'),
    );
  });

  test('medicine start is converted to Dhaka wall-clock time', () {
    final m = Medicine(
      id: 'x',
      name: 'Seclo',
      dosePattern: '1+0+1',
      startAt: DateTime.utc(2026, 11, 26, 20, 30),
    );
    expect(m.toScheduleInput().start, DateTime.utc(2026, 11, 27, 2, 30));
  });
}
