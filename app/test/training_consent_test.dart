import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/data/training_consent.dart';
import 'package:oshudh_reminder/screens/settings_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';

import 'helpers.dart';

void main() {
  late FakeBackendApi api;
  late InMemoryTrainingConsentRepository consent;
  late AppState state;

  Future<void> setUpState() async {
    api = FakeBackendApi();
    consent = InMemoryTrainingConsentRepository();
    state = AppState(
      auth: DemoAuthRepository(),
      medicines: InMemoryMedicineRepository(now: fixedNow),
      api: api,
      trainingConsent: consent,
      clock: fixedNow,
    );
    await state.auth.verifyCode('+8801712345678', '123456');
  }

  List<MedicineDraft> reviewedDrafts() {
    final scan = PrescriptionScan.fromJson(exampleScanJson());
    return [
      for (final m in scan.medicines)
        MedicineDraft.fromScan(m)..fields.forEach((f) => f.markReviewed()),
    ];
  }

  test('nothing is shared without consent', () async {
    await setUpState();
    await state.confirm(
      reviewedDrafts(),
      source: 'scan',
      scanImage: Uint8List(8),
    );
    expect(api.trainingLabels, isEmpty);
  });

  test(
    'with consent, the confirmed values are shared without free text',
    () async {
      await setUpState();
      consent.granted = true;
      await state.confirm(
        reviewedDrafts(),
        source: 'scan',
        scanImage: Uint8List(8),
      );
      final medicines = api.trainingLabels.single['medicines'] as List;
      expect(medicines, hasLength(3));
      expect((medicines.first as Map).keys.toSet(), {
        'name',
        'strength',
        'dose_pattern',
        'timing',
        'duration_days',
        'continue_indefinitely',
        'as_needed',
      });
      expect(medicines.first['name'], 'Seclo');
    },
  );

  test('manual entries are never shared (there is no photo)', () async {
    await setUpState();
    consent.granted = true;
    final d = MedicineDraft.manual()
      ..name.edit('Napa')
      ..dose.edit('1+1+1')
      ..durationDays.edit(5);
    await state.confirm([d], source: 'manual');
    expect(api.trainingLabels, isEmpty);
  });

  testWidgets('the consent switch is off by default and can be turned on', (
    tester,
  ) async {
    await setUpState();
    await pumpApp(tester, state);
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('trainingConsent'));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(consent.granted, isTrue);
  });
}

class RecordingRepository extends InMemoryMedicineRepository {
  RecordingRepository() : super(now: fixedNow);

  final List<String?> savedFor = [];

  @override
  Future<void> saveConfirmed(
    List<MedicineDraft> drafts, {
    required String source,
    String? imageQuality,
    String? forUserId,
  }) async {
    savedFor.add(forUserId);
    if (forUserId == null) {
      await super.saveConfirmed(
        drafts,
        source: source,
        imageQuality: imageQuality,
      );
    }
  }
}
