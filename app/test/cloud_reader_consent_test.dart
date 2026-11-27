import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/screens/confirm_screen.dart';
import 'package:oshudh_reminder/screens/scan_screen.dart';
import 'package:oshudh_reminder/screens/settings_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<(AppState, FakeBackendApi)> _app(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final api = FakeBackendApi();
  final state = AppState(
    auth: DemoAuthRepository(),
    medicines: InMemoryMedicineRepository(now: fixedNow),
    api: api,
    store: LocalStore(await SharedPreferences.getInstance()),
    clock: fixedNow,
  );
  await state.auth.verifyCode('+8801712345678', '123456');
  await pumpApp(tester, state);
  return (state, api);
}

Future<void> _openScan(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Scaffold).first)).push(
    MaterialPageRoute<void>(
      builder: (_) => ScanScreen(
        pickImage: ({required bool camera}) async => Uint8List(4),
        retryDelay: Duration.zero,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scanFromGallery(WidgetTester tester) async {
  await tester.tap(find.text('গ্যালারি থেকে বেছে নিন'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the first scan asks once; "Allow" sends hard photos to the cloud reader',
    (tester) async {
      final (state, api) = await _app(tester);
      await _openScan(tester);
      await _scanFromGallery(tester);
      expect(find.byKey(const Key('cloudReaderAllow')), findsOneWidget);
      expect(api.extractCalls, 0); // nothing is read before the user decides
      await tester.tap(find.byKey(const Key('cloudReaderAllow')));
      await tester.pumpAndSettle();
      expect(state.cloudReaderConsent, isTrue);
      expect(api.cloudOks, [true]);
      expect(find.byType(ConfirmScreen), findsOneWidget);

      // Not asked again
      await _openScan(tester);
      await _scanFromGallery(tester);
      expect(find.byKey(const Key('cloudReaderAllow')), findsNothing);
      expect(api.cloudOks, [true, true]);
    },
  );

  testWidgets('"No" keeps every photo on our own server', (tester) async {
    final (state, api) = await _app(tester);
    await _openScan(tester);
    await _scanFromGallery(tester);
    await tester.tap(find.byKey(const Key('cloudReaderDeny')));
    await tester.pumpAndSettle();
    expect(state.cloudReaderConsent, isFalse);
    expect(api.cloudOks, [false]);
  });

  testWidgets('the choice can be changed in Settings', (tester) async {
    final (state, _) = await _app(tester);
    await state.setCloudReaderConsent(false);
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('cloudReaderConsent'));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(state.cloudReaderConsent, isTrue);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });
}
