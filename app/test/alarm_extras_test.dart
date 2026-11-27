// Snoozes and the test alarm must survive a re-sync, and answering a snoozed alarm records the
// original dose.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/alarm_payload.dart';
import 'package:oshudh_reminder/alarms/alarm_planner.dart';
import 'package:oshudh_reminder/alarms/alarm_scheduler.dart';
import 'package:oshudh_reminder/alarms/alarm_service.dart';
import 'package:oshudh_reminder/alarms/dose_log.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/screens/setup_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  late LocalStore store;
  late FakeAlarmScheduler scheduler;
  late AlarmService service;
  var now = DateTime.utc(2026, 11, 26, 15); // 21:00 in Dhaka

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance());
    scheduler = FakeAlarmScheduler();
    now = DateTime.utc(2026, 11, 26, 15);
    service = AlarmService(
      store: store,
      scheduler: scheduler,
      clock: () => now,
    );
  });

  final dose = AlarmPayload(DateTime.utc(2026, 11, 26, 21), const [
    AlarmItem('seclo', 'Seclo 20 mg', '1'),
  ]);

  test('a snoozed alarm is still scheduled after the app re-syncs', () async {
    await service.snooze(dose);
    await service.sync(); // e.g. the app was opened: every alarm is replaced
    final snoozed = scheduler.pending.where(
      (a) => a.items.first.medicineId == 'seclo',
    );
    expect(snoozed, hasLength(1));
    expect(snoozed.single.at, DateTime.utc(2026, 11, 26, 21, 10));
  });

  test('answering a snoozed alarm records the original dose time', () async {
    await service.snooze(dose);
    final snoozedPayload = AlarmPayload.fromSpec(scheduler.extra.single);
    expect(snoozedPayload.at, dose.at); // not 21:10
    await service.record(snoozedPayload, DoseStatus.taken);
    expect(store.logs().single.scheduledAt, dose.at);
  });

  test('the snooze limit counts snoozes of the same dose', () async {
    for (var i = 0; i < maxSnoozes; i++) {
      expect(
        await service.snooze(
          AlarmPayload.fromSpec(
            i == 0
                ? AlarmSpec(id: 1, at: dose.at, items: dose.items)
                : scheduler.extra.last,
          ),
        ),
        SnoozeResult.snoozed,
      );
    }
    expect(
      await service.snooze(AlarmPayload.fromSpec(scheduler.extra.last)),
      SnoozeResult.limitReached,
    );
  });

  test('past snoozes are not scheduled again', () async {
    await service.snooze(dose);
    now = now.add(const Duration(minutes: 30));
    await service.sync();
    expect(
      scheduler.pending.where((a) => a.items.first.medicineId == 'seclo'),
      isEmpty,
    );
  });

  test('the test alarm rings within a minute and records nothing', () async {
    final at = await service.scheduleTestAlarm('Test');
    expect(at, DateTime.utc(2026, 11, 26, 21, 1));
    await service.sync();
    expect(
      scheduler.pending.where(
        (a) => a.items.first.medicineId == testAlarmMedicineId,
      ),
      hasLength(1),
    );
    await service.record(
      AlarmPayload.fromSpec(scheduler.extra.single),
      DoseStatus.taken,
    );
    expect(store.logs(), isEmpty);
  });

  testWidgets('Reminder settings offers a test alarm', (tester) async {
    final state = AppState(
      auth: DemoAuthRepository(),
      medicines: InMemoryMedicineRepository(now: fixedNow),
      api: FakeBackendApi(),
      store: store,
      alarms: service,
      clock: fixedNow,
    );
    await pumpApp(tester, state);
    Navigator.of(tester.element(find.byType(Scaffold).first)).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SetupScreen(notifications: FlutterLocalNotificationsPlugin()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('testAlarm')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('testAlarm')));
    await tester.pump();
    expect(scheduler.extra.single.items.single.medicineId, testAlarmMedicineId);
    expect(find.textContaining('এক মিনিটের মধ্যে'), findsOneWidget);
  });
}
