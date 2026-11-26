import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/alarms/alarm_payload.dart';
import 'package:oshudh_reminder/alarms/alarm_planner.dart';
import 'package:oshudh_reminder/alarms/alarm_scheduler.dart';
import 'package:oshudh_reminder/alarms/alarm_service.dart';
import 'package:oshudh_reminder/alarms/battery_guide.dart';
import 'package:oshudh_reminder/alarms/dose_log.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 2026-11-26 10:00 in Dhaka (UTC+6)
final now = DateTime.utc(2026, 11, 26, 4);
final wallNow = DateTime.utc(2026, 11, 26, 10);

Medicine med(
  String id,
  String pattern, {
  Timing timing = Timing.beforeMeal,
  int? days = 30,
  bool asNeeded = false,
}) => Medicine(
  id: id,
  name: id,
  strength: '20 mg',
  dosePattern: asNeeded ? null : pattern,
  timing: timing,
  durationDays: days,
  asNeeded: asNeeded,
  startAt: now,
);

Future<LocalStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStore(await SharedPreferences.getInstance());
}

void main() {
  group('planAlarms', () {
    test('plans grouped alarms for the next 7 days', () {
      final alarms = planAlarms(
        medicines: [
          med('seclo', '1+0+1'),
          med('napa', '1+1+1', timing: Timing.afterMeal, days: 5),
        ],
        settings: const ScheduleSettings(),
        wallNow: wallNow,
      );
      final doses = alarms.where((a) => !a.isHorizonNotice).toList();
      // First alarm: napa after lunch at 13:45 (seclo's morning dose is already past)
      expect(doses.first.at, DateTime.utc(2026, 11, 26, 13, 45));
      expect(doses.first.items.single.label, 'napa 20 mg');
      expect(doses.every((a) => !a.at.isBefore(wallNow)), isTrue);
      expect(
        doses.last.at.isBefore(wallNow.add(const Duration(days: 7))),
        isTrue,
      );
      // napa's 5-day course = 15 doses from the 13:45 dose onward
      expect(
        doses.expand((a) => a.items).where((i) => i.medicineId == 'napa'),
        hasLength(15),
      );
      expect(alarms.last.isHorizonNotice, isTrue);
      expect(alarms.last.id, horizonNoticeId);
    });

    test('ids are stable across re-plans and unique', () {
      List<int> ids() => planAlarms(
        medicines: [med('seclo', '1+0+1')],
        settings: const ScheduleSettings(),
        wallNow: wallNow,
      ).map((a) => a.id).toList();
      expect(ids(), ids());
      expect(ids().toSet(), hasLength(ids().length));
    });

    test(
      'handled doses are dropped; partially handled reminders keep the rest',
      () {
        final tonight = DateTime.utc(2026, 11, 26, 21);
        final alarms = planAlarms(
          medicines: [med('a', '1+0+1'), med('b', '1+0+1')],
          settings: const ScheduleSettings(),
          wallNow: wallNow,
          handledKeys: {doseKey('a', tonight)},
        );
        final first = alarms.first;
        expect(first.at, tonight);
        expect(first.items.map((i) => i.medicineId), ['b']);
      },
    );

    test('as-needed medicines and empty lists produce no alarms', () {
      expect(
        planAlarms(
          medicines: [med('sos', '', asNeeded: true)],
          settings: const ScheduleSettings(),
          wallNow: wallNow,
        ),
        isEmpty,
      );
      expect(
        planAlarms(
          medicines: const [],
          settings: const ScheduleSettings(),
          wallNow: wallNow,
        ),
        isEmpty,
      );
    });

    test('never schedules more than the cap', () {
      final meds = [
        for (var i = 0; i < 10; i++)
          med('m$i', '1+1+1+1', timing: Timing.values[i % 6]),
      ];
      final alarms = planAlarms(
        medicines: meds,
        settings: const ScheduleSettings(groupWindowMinutes: 0),
        wallNow: wallNow,
      );
      expect(
        alarms.where((a) => !a.isHorizonNotice).length,
        lessThanOrEqualTo(maxAlarms),
      );
    });
  });

  test('payload round-trips through a notification', () {
    final p = AlarmPayload(DateTime.utc(2026, 11, 26, 21), const [
      AlarmItem('seclo', 'Seclo 20 mg', '1'),
    ]);
    final back = AlarmPayload.decode(p.encode());
    expect(back.at, p.at);
    expect(back.items.single.label, 'Seclo 20 mg');
    expect(back.reminderKey, p.reminderKey);
  });

  group('AlarmService', () {
    late LocalStore store;
    late FakeAlarmScheduler scheduler;
    late AlarmService service;

    setUp(() async {
      store = await freshStore();
      scheduler = FakeAlarmScheduler();
      service = AlarmService(
        store: store,
        scheduler: scheduler,
        clock: () => now,
      );
      await store.saveMedicines([med('seclo', '1+0+1')]);
    });

    test('sync schedules from the offline cache', () async {
      final n = await service.sync();
      expect(n, 14); // 2 per day; today's morning dose is past, plus tomorrow+6 → 1 + 2*6 + 1
      expect(scheduler.pending.first.at, DateTime.utc(2026, 11, 26, 21));
    });

    test('taken is logged and that alarm is not scheduled again', () async {
      await service.sync();
      final first = scheduler.pending.first;
      await service.handleAction(
        actionTaken,
        AlarmPayload.fromSpec(first).encode(),
      );
      expect(store.logs().single.status, DoseStatus.taken);
      expect(scheduler.pending.first.at, isNot(first.at));
    });

    test('skip is logged as skipped', () async {
      await service.sync();
      await service.handleAction(
        actionSkip,
        AlarmPayload.fromSpec(scheduler.pending.first).encode(),
      );
      expect(store.logs().single.status, DoseStatus.skipped);
    });

    test('snooze schedules 10 minutes later, at most 3 times', () async {
      await service.sync();
      final payload = AlarmPayload.fromSpec(scheduler.pending.first);
      for (var i = 0; i < maxSnoozes; i++) {
        expect(await service.snooze(payload), SnoozeResult.snoozed);
      }
      expect(await service.snooze(payload), SnoozeResult.limitReached);
      expect(scheduler.extra, hasLength(3));
      expect(
        scheduler.extra.first.at,
        wallNow.add(const Duration(minutes: 10)),
      );
      expect(scheduler.extra.first.items.single.medicineId, 'seclo');
      expect(scheduler.extra.map((a) => a.id).toSet(), hasLength(3));
    });
  });

  group('LocalStore', () {
    test('medicines, settings and logs survive a restart', () async {
      final store = await freshStore();
      await store.saveMedicines([med('seclo', '1+0+1')]);
      await store.saveSettings(const ScheduleSettings(dinner: 22 * 60));
      await store.addLog(
        DoseLog(
          medicineId: 'seclo',
          scheduledAt: DateTime.utc(2026, 11, 26, 21),
          status: DoseStatus.taken,
          actedAt: now,
        ),
      );
      final reopened = LocalStore(await SharedPreferences.getInstance());
      expect(reopened.loadMedicines().single.dosePattern, '1+0+1');
      expect(reopened.loadSettings().dinner, 22 * 60);
      expect(reopened.unsyncedLogs(), hasLength(1));
      await reopened.markSynced(reopened.logs().map((l) => l.key));
      expect(reopened.unsyncedLogs(), isEmpty);
    });

    test('old synced logs are pruned, unsynced ones are kept', () async {
      final store = await freshStore();
      final old = now.subtract(const Duration(days: 120));
      await store.addLog(
        DoseLog(
          medicineId: 'a',
          scheduledAt: DateTime.utc(2026, 7, 1, 8),
          status: DoseStatus.taken,
          actedAt: old,
          synced: true,
        ),
      );
      await store.addLog(
        DoseLog(
          medicineId: 'b',
          scheduledAt: DateTime.utc(2026, 7, 1, 8),
          status: DoseStatus.taken,
          actedAt: old,
        ),
      );
      await store.addLog(
        DoseLog(
          medicineId: 'c',
          scheduledAt: DateTime.utc(2026, 11, 26, 8),
          status: DoseStatus.taken,
          actedAt: now,
        ),
        now: now,
      );
      expect(store.logs().map((l) => l.medicineId), ['b', 'c']);
    });
  });

  group('battery guide', () {
    const cases = {
      'Xiaomi': 'xiaomi',
      'Redmi': 'xiaomi',
      'POCO': 'xiaomi',
      'realme': 'oppo',
      'OPPO': 'oppo',
      'vivo': 'vivo',
      'samsung': 'samsung',
      'HUAWEI': 'huawei',
      'Symphony': 'generic',
      'WALTON': 'generic',
    };
    cases.forEach((manufacturer, brand) {
      test(
        '$manufacturer → $brand',
        () => expect(batteryGuideFor(manufacturer).brand, brand),
      );
    });
    test(
      'generic phones use the standard settings screen',
      () => expect(batteryGuideFor('Tecno').targets, isEmpty),
    );
  });
}
