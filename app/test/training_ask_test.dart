import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/data/training_consent.dart';
import 'package:oshudh_reminder/screens/confirm_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

late FakeBackendApi api;
late InMemoryTrainingConsentRepository consent;

Future<AppState> appState() async {
  SharedPreferences.setMockInitialValues({});
  api = FakeBackendApi();
  consent = InMemoryTrainingConsentRepository();
  final state = AppState(
    auth: DemoAuthRepository(),
    medicines: InMemoryMedicineRepository(now: fixedNow),
    api: api,
    store: LocalStore(await SharedPreferences.getInstance()),
    trainingConsent: consent,
    clock: fixedNow,
  );
  await state.auth.verifyCode('+8801712345678', '123456');
  return state;
}

List<MedicineDraft> reviewed() => [
  for (final m in PrescriptionScan.fromJson(exampleScanJson()).medicines)
    MedicineDraft.fromScan(m)..fields.forEach((f) => f.markReviewed()),
];

/// Opens the confirm screen for a scan (or a manual entry) and taps Confirm.
Future<void> confirmScan(
  WidgetTester tester,
  AppState state, {
  bool scanned = true,
}) async {
  Navigator.of(tester.element(find.byType(Scaffold).first)).push(
    MaterialPageRoute<void>(
      builder: (_) => ConfirmScreen(
        drafts: reviewed(),
        source: scanned ? 'scan' : 'manual',
        image: scanned ? Uint8List(8) : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final confirm = find.byKey(const Key('confirm'));
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"Yes" after the first scan turns sharing on and shares it', (
    tester,
  ) async {
    final state = await appState();
    await pumpApp(tester, state);
    await confirmScan(tester, state);
    expect(find.text('অ্যাপকে আরও ভালো পড়তে শেখাবেন?'), findsOneWidget);
    expect(api.trainingLabels, isEmpty); // nothing before the answer
    await tester.tap(find.byKey(const Key('trainingAskYes')));
    await tester.pumpAndSettle();
    expect(consent.granted, isTrue);
    expect(api.trainingLabels, hasLength(1));
    expect(state.active, isNotEmpty); // the medicines were saved

    // Asked only once; later scans are shared as agreed
    await confirmScan(tester, state);
    expect(find.byKey(const Key('trainingAskYes')), findsNothing);
    expect(api.trainingLabels, hasLength(2));
  });

  testWidgets('"No" shares nothing and is not asked again', (tester) async {
    final state = await appState();
    await pumpApp(tester, state);
    await confirmScan(tester, state);
    await tester.tap(find.byKey(const Key('trainingAskNo')));
    await tester.pumpAndSettle();
    expect(consent.granted, isFalse);
    expect(api.trainingLabels, isEmpty);
    expect(state.active, isNotEmpty);

    await confirmScan(tester, state);
    expect(find.byKey(const Key('trainingAskNo')), findsNothing);
    expect(api.trainingLabels, isEmpty);
  });

  testWidgets('not asked for a medicine typed in by hand', (tester) async {
    final state = await appState();
    await pumpApp(tester, state);
    await confirmScan(tester, state, scanned: false);
    expect(find.byKey(const Key('trainingAskYes')), findsNothing);
  });

  testWidgets('not asked when sharing is already on', (tester) async {
    final state = await appState();
    consent.granted = true;
    await pumpApp(tester, state);
    await confirmScan(tester, state);
    expect(find.byKey(const Key('trainingAskYes')), findsNothing);
    expect(api.trainingLabels, hasLength(1));
  });
}
