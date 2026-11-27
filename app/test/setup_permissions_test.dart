import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/screens/setup_screen.dart';

import 'helpers.dart';

class _FakePermissions implements AlarmPermissions {
  bool? notifications = false;
  bool? exact = true;
  bool throwOnRequest = false;
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
  Future<bool?> requestNotifications() => _ask(notifications);
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
}
