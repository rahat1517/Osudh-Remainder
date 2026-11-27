import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/state/app_state.dart';
import 'package:oshudh_reminder/updates/update_checker.dart';

import 'helpers.dart';

final _manifest = Uri.parse('https://x.supabase.co/latest.json');

UpdateChecker _checker(
  Object body, {
  int installed = 10,
  List<String> abis = const ['arm64-v8a', 'armeabi-v7a'],
  int status = 200,
}) => UpdateChecker(
  manifestUrl: _manifest,
  installedBuild: installed,
  supportedAbis: () async => abis,
  client: MockClient((_) async => http.Response(jsonEncode(body), status)),
);

const _latest = {
  'build': 12,
  'notes': 'Fixes',
  'apks': {
    'arm64-v8a': 'https://x/12-arm64.apk',
    'armeabi-v7a': 'https://x/12-v7a.apk',
  },
};

void main() {
  test('a newer build offers the APK for this phone', () async {
    final u = await _checker(_latest).check();
    expect(u?.build, 12);
    expect(u?.url, 'https://x/12-arm64.apk');
    final old = await _checker(_latest, abis: ['armeabi-v7a']).check();
    expect(old?.url, 'https://x/12-v7a.apk');
  });

  test(
    'no update when current, unknown phone type, offline or a dev build',
    () async {
      expect(await _checker(_latest, installed: 12).check(), isNull);
      expect(await _checker(_latest, abis: ['x86_64']).check(), isNull);
      expect(await _checker(_latest, status: 404).check(), isNull);
      expect(await _checker('not json').check(), isNull);
      expect(await _checker({'build': 'x', 'apks': 1}).check(), isNull);
      expect(await _checker(_latest, installed: 0).check(), isNull);
      final offline = UpdateChecker(
        manifestUrl: _manifest,
        installedBuild: 10,
        supportedAbis: () async => ['arm64-v8a'],
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(await offline.check(), isNull);
    },
  );

  testWidgets('home shows the update banner', (tester) async {
    final state = AppState(
      auth: DemoAuthRepository(),
      medicines: InMemoryMedicineRepository(now: fixedNow),
      api: FakeBackendApi(),
      updates: _checker(_latest),
      clock: fixedNow,
    );
    await state.auth.verifyCode('+8801712345678', '123456');
    await pumpApp(tester, state);
    expect(find.byKey(const Key('updateBanner')), findsNothing);
    await state.checkForUpdate();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('updateBanner')), findsOneWidget);
    expect(find.text('আপডেট করুন'), findsOneWidget);
  });
}
