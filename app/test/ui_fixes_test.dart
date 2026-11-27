// Regressions found by looking at every screen at phone size (human-style review).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/alarm_scheduler.dart';
import 'package:oshudh_reminder/alarms/alarm_service.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:oshudh_reminder/screens/confirm_screen.dart';
import 'package:oshudh_reminder/screens/medicines_screen.dart';
import 'package:oshudh_reminder/screens/report_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

MedicineDraft _draft(
  String name,
  String dose, {
  int? days,
  String? generic,
  String? strength,
}) {
  final d = MedicineDraft.manual()
    ..name.edit(name)
    ..dose.edit(dose)
    ..timing.edit(Timing.notSpecified);
  if (strength != null) d.strength.edit(strength);
  if (days == null) {
    d.continueIndefinitely = true;
  } else {
    d.durationDays.edit(days);
  }
  d.generic = generic;
  return d;
}

Future<AppState> _signedIn(List<MedicineDraft> drafts) async {
  final state = demoState();
  await state.auth.verifyCode('+8801712345678', '123456');
  if (drafts.isNotEmpty) await state.confirm(drafts, source: 'manual');
  return state;
}

Future<void> _phone(WidgetTester tester, AppState state) async {
  await pumpApp(tester, state);
  // A common Android phone: 360 × 800 dp
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, Widget screen) async {
  Navigator.of(tester.element(find.byType(Scaffold).first))
      .push(MaterialPageRoute<void>(builder: (_) => screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the home title is not cut off on a phone', (tester) async {
    await _phone(tester, await _signedIn([_draft('Napa', '1+1+1', days: 5)]));
    // Five icons left no room for the title ("আজ..."); three and a menu fit (checked with the
    // real font in test/screen_tour_test.dart; widget tests draw text with a box font)
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ),
      findsNWidgets(4), // three icons + the menu button
    );
    // The assistant (and family, when available) moved into the menu
    await tester.tap(find.byKey(const Key('homeMenu')));
    await tester.pumpAndSettle();
    expect(find.text('ওষুধ নিয়ে জিজ্ঞেস করুন'), findsOneWidget);
  });

  testWidgets('half tablets read as ½ and numbers in Bangla digits', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final state = AppState(
      auth: DemoAuthRepository(),
      medicines: InMemoryMedicineRepository(now: fixedNow),
      api: FakeBackendApi(),
      store: store,
      alarms: AlarmService(
        store: store,
        scheduler: FakeAlarmScheduler(),
        clock: fixedNow,
      ),
      clock: fixedNow,
    );
    await state.auth.verifyCode('+8801712345678', '123456');
    await state.confirm([
      _draft('Rivotril', '0.5+0+0.5', strength: '0.5 mg'),
    ], source: 'manual');
    await _phone(tester, state);
    expect(find.textContaining('×\u00A0½'), findsWidgets); // was "× 0.5"
    expect(find.textContaining(RegExp('[০-৯]+টি রিমাইন্ডার')), findsOneWidget);
    expect(find.textContaining(RegExp('[0-9]+টি রিমাইন্ডার')), findsNothing);
  });

  testWidgets(
    'medicines list: plain duration, ½ pattern, labelled stop, no sign-out',
    (tester) async {
      await _phone(
        tester,
        await _signedIn([
          _draft('Seclo', '1+0+1', days: 30),
          _draft('Rivotril', '0.5+0+0.5'),
        ]),
      );
      await _open(tester, const MedicinesScreen());
      expect(find.textContaining('৩০ দিন'), findsOneWidget); // was "30 কত দিন"
      expect(find.textContaining('কত দিন'), findsNothing);
      expect(find.textContaining('½+0+½'), findsOneWidget);
      expect(find.text('বন্ধ'), findsNWidgets(2));
      expect(find.byIcon(Icons.logout), findsNothing);
    },
  );

  testWidgets('the report does not claim 100% when nothing was due', (
    tester,
  ) async {
    await _phone(tester, await _signedIn([_draft('Seclo', '1+0+1', days: 30)]));
    await _open(tester, const ReportScreen());
    expect(find.textContaining('100%'), findsNothing);
    expect(find.textContaining('এখনো কোনো ডোজের সময় হয়নি'), findsOneWidget);
  });

  testWidgets('a new manual entry starts clean', (tester) async {
    await _phone(
      tester,
      await _signedIn([
        _draft('Napa', '1+1+1', days: 5, generic: 'Paracetamol'),
        _draft('Ace', '1+0+1', days: 3, generic: 'Paracetamol'),
      ]),
    );
    await _open(tester, ConfirmScreen.manual());
    // The existing duplicate is shown on the home screen, not on an unrelated new entry
    expect(find.text('একই ওষুধ দুইবার?'), findsNothing);
    // No list of errors before the user has typed anything
    expect(find.text('ওষুধের নাম লিখুন'), findsNothing);
    await tester.enterText(find.byKey(const Key('name')), 'X');
    await tester.pumpAndSettle();
    expect(find.textContaining('ডোজ লিখুন'), findsOneWidget);
  });
}
