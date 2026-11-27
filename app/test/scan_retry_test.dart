import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/data/backend_api.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/screens/confirm_screen.dart';
import 'package:oshudh_reminder/screens/scan_screen.dart';

import 'helpers.dart';

/// Fails the first [failures] reads with [code], then reads normally.
class FlakyApi extends FakeBackendApi {
  FlakyApi(this.failures, {this.code = 'network_error'});

  int failures;
  final String code;

  @override
  Future<PrescriptionScan> extractPrescription(
    Uint8List image, {
    String filename = 'rx.jpg',
  }) async {
    extractCalls++;
    if (failures > 0) {
      failures--;
      throw ApiException(code);
    }
    return PrescriptionScan.fromJson(exampleScanJson());
  }
}

Future<void> openScan(WidgetTester tester, FakeBackendApi api) async {
  final state = demoState(api: api);
  await state.auth.verifyCode('+8801712345678', '123456');
  await pumpApp(tester, state);
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

void main() {
  testWidgets('one dropped connection is retried without asking', (
    tester,
  ) async {
    final api = FlakyApi(1);
    await openScan(tester, api);
    await tester.tap(find.text('গ্যালারি থেকে বেছে নিন'));
    await tester.pumpAndSettle();
    expect(api.extractCalls, 2);
    expect(find.byType(ConfirmScreen), findsOneWidget);
  });

  testWidgets('"Try again" reuses the photo after repeated failures', (
    tester,
  ) async {
    final api = FlakyApi(2, code: 'server_error');
    var picks = 0;
    final state = demoState(api: api);
    await state.auth.verifyCode('+8801712345678', '123456');
    await pumpApp(tester, state);
    Navigator.of(tester.element(find.byType(Scaffold).first)).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanScreen(
          pickImage: ({required bool camera}) async {
            picks++;
            return Uint8List(4);
          },
          retryDelay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ছবি তুলুন'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retryScan')), findsOneWidget);
    expect(find.text('নিজে যোগ করুন'), findsOneWidget);
    await tester.tap(find.byKey(const Key('retryScan')));
    await tester.pumpAndSettle();
    expect(picks, 1); // no new photo needed
    expect(api.extractCalls, 3);
    expect(find.byType(ConfirmScreen), findsOneWidget);
  });

  testWidgets('no "Try again" when retrying cannot help', (tester) async {
    final api = FlakyApi(5, code: 'not_a_prescription');
    await openScan(tester, api);
    await tester.tap(find.text('গ্যালারি থেকে বেছে নিন'));
    await tester.pumpAndSettle();
    expect(api.extractCalls, 1);
    expect(find.text('এটা প্রেসক্রিপশন মনে হচ্ছে না।'), findsOneWidget);
    expect(find.byKey(const Key('retryScan')), findsNothing);
  });

  testWidgets('the buttons stay above the navigation bar', (tester) async {
    await openScan(tester, FakeBackendApi());
    // A phone that draws the app behind a 48 dp navigation bar
    tester.view.padding = const FakeViewPadding(bottom: 48 * 2.5);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48 * 2.5);
    await tester.pumpAndSettle();
    final screenHeight = tester.view.physicalSize.height / 2.5;
    final gallery = tester.getRect(
      find.ancestor(
        of: find.text('গ্যালারি থেকে বেছে নিন'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(gallery.bottom, lessThanOrEqualTo(screenHeight - 48));
  });
}
