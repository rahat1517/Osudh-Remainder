import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/alarm_permissions.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/screens/setup_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';

import 'helpers.dart';

class _FakePermissions implements AlarmPermissions {
  bool? notifications = false;
  bool? exact = true;
  bool throwOnRequest = false;
  bool grantOnRequest = false;
  int requests = 0;

  Future<bool?> _ask(bool? result) async {
    requests++;
    if (throwOnRequest) throw Exception('request in progress');
    return result;
  }

  @override
  Future<bool?> notificationsAllowed() async => notifications;
  @override
  Future<bool?> exactAlarmsAllowed() async => exact;
  @override
  Future<bool?> requestNotifications() async {
    final r = await _ask(notifications);
    if (grantOnRequest) notifications = true;
    return r;
  }

  @override
  Future<bool?> requestExactAlarms() => _ask(exact);
  @override
  Future<bool?> requestFullScreen() => _ask(true);
}

Future<_FakePermissions> _open(WidgetTester tester, _FakePermissions p) async {
  await pumpApp(tester, demoState());
  Navigator.of(tester.element(find.byType(Scaffold).first)).push(
    MaterialPageRoute<void>(
      builder: (_) => SetupScreen(
        notifications: FlutterLocalNotificationsPlugin(),
        permissions: p,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return p;
}

Finder _in(String key, Finder f) =>
    find.descendant(of: find.byKey(Key(key)), matching: f);

void main() {
  testWidgets(
    'a permission that is already on says so instead of a dead button',
    (tester) async {
      await _open(tester, _FakePermissions());
      // Exact alarms granted: no button that would open nothing
      expect(_in('setup-exact', find.text('চালু আছে')), findsOneWidget);
      expect(_in('setup-exact', find.byType(FilledButton)), findsNothing);
      // Notifications not granted yet: the button is there
      expect(_in('setup-notifications', find.text('খুলুন')), findsOneWidget);
    },
  );

  testWidgets('granting shows the new state', (tester) async {
    final p = await _open(tester, _FakePermissions());
    p.notifications = true; // the user allows it in the system dialog
    await tester.tap(_in('setup-notifications', find.text('খুলুন')));
    await tester.pumpAndSettle();
    expect(_in('setup-notifications', find.text('চালু আছে')), findsOneWidget);
    expect(find.text('এটা আগে থেকেই চালু আছে ✓'), findsOneWidget);
  });

  testWidgets('a failed request explains instead of doing nothing', (
    tester,
  ) async {
    final p = await _open(tester, _FakePermissions()..throwOnRequest = true);
    await tester.tap(_in('setup-notifications', find.text('খুলুন')));
    await tester.pumpAndSettle();
    expect(p.requests, 1);
    expect(find.text('এখন খোলা যায়নি। একটু পরে আবার চাপুন।'), findsOneWidget);
  });

  testWidgets('returning from the phone settings refreshes the status', (
    tester,
  ) async {
    final p = await _open(tester, _FakePermissions()..exact = false);
    expect(_in('setup-exact', find.text('খুলুন')), findsOneWidget);
    p.exact = true; // turned on in Settings → Alarms & reminders
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_in('setup-exact', find.text('চালু আছে')), findsOneWidget);
  });

  group('a new user', () {
    MedicineDraft napa() => MedicineDraft.manual()
      ..name.edit('Napa')
      ..dose.edit('1+1+1')
      ..durationDays.edit(5);

    AppState stateWith(_FakePermissions p) => AppState(
      auth: DemoAuthRepository(),
      medicines: InMemoryMedicineRepository(now: fixedNow),
      api: FakeBackendApi(),
      permissions: p,
      clock: fixedNow,
    );

    test(
      'is asked for notifications when the first medicine is saved',
      () async {
        final p = _FakePermissions()..grantOnRequest = true;
        final state = stateWith(p);
        await state.auth.verifyCode('+8801712345678', '123456');
        await state.confirm([napa()], source: 'manual');
        expect(p.requests, 1); // the system dialog was shown
        expect(state.alarmsBlocked, isFalse);
        await state.confirm([napa()], source: 'manual');
        expect(p.requests, 1); // only the first time
      },
    );

    testWidgets('sees a warning on home while alarms cannot ring', (
      tester,
    ) async {
      final p = _FakePermissions(); // the user said no in the dialog
      final state = stateWith(p);
      await state.auth.verifyCode('+8801712345678', '123456');
      await state.confirm([napa()], source: 'manual');
      expect(state.alarmsBlocked, isTrue);
      await pumpApp(tester, state);
      expect(find.byKey(const Key('alarmsBlocked')), findsOneWidget);
      expect(find.text('অ্যালার্ম বাজবে না'), findsOneWidget);
      p.notifications = true; // allowed in Reminder settings
      await state.checkAlarmPermissions();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('alarmsBlocked')), findsNothing);
    });
  });
}
