import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/alarms/alarm_payload.dart';
import 'package:oshudh_reminder/alarms/alarm_scheduler.dart';
import 'package:oshudh_reminder/alarms/alarm_service.dart';
import 'package:oshudh_reminder/alarms/dose_log.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/l10n/generated/app_localizations.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:oshudh_reminder/widget/dose_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 2026-11-26 10:00 in Dhaka (UTC+6)
final now = DateTime.utc(2026, 11, 26, 4);
final wallNow = DateTime.utc(2026, 11, 26, 10);
final l = lookupAppLocalizations(const Locale('bn'));

Medicine napa() => Medicine(
  id: 'napa',
  name: 'Napa',
  strength: '500 mg',
  dosePattern: '1+1+1',
  timing: Timing.afterMeal,
  durationDays: 5,
  startAt: now.subtract(const Duration(days: 1)),
);

List<Map<String, Object?>> entries(Map<String, Object?> s) =>
    (s['entries']! as List).cast<Map<String, Object?>>();

DateTime instant(Object? ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms! as int, isUtc: true);

/// Wall-clock time (Dhaka) of an entry.
DateTime wall(Map<String, Object?> e) =>
    instant(e['at']).add(const Duration(hours: 6));

AlarmPayload payloadOf(Map<String, Object?> e) => AlarmPayload.decode(
  Uri.parse(e['takenUri']! as String).queryParameters['payload']!,
);

Map<String, Object?> snapshotAt(
  DateTime wallTime, {
  Set<String> handled = const {},
  List<Medicine>? medicines,
}) => buildWidgetSnapshot(
  medicines: medicines ?? [napa()],
  settings: const ScheduleSettings(),
  wallNow: wallTime,
  handledKeys: handled,
  l: l,
);

class ThrowingPublisher implements WidgetPublisher {
  @override
  Future<void> publish(Map<String, Object?> s, List<DateTime> r) async =>
      throw StateError('no launcher support');
}

void main() {
  test('lists upcoming doses with times worked out for the widget', () {
    final s = snapshotAt(wallNow);
    final first = entries(s).first;
    // Napa after lunch, 13:45
    expect(wall(first), DateTime.utc(2026, 11, 26, 13, 45));
    expect(first['time'], '১৩:৪৫');
    expect(first['medicines'], 'Napa 500 mg × ১');
    expect(
      instant(first['dueFrom']),
      instant(first['at']).subtract(const Duration(minutes: 30)),
    );
    expect(
      instant(first['until']),
      instant(first['at']).add(const Duration(minutes: 60)),
    );
    // Local midnight of that day, as a real instant (18:00 UTC the day before)
    expect(instant(first['dayStart']), DateTime.utc(2026, 11, 25, 18));
    // Later doses come in order, tomorrow included
    final times = [for (final e in entries(s)) wall(e)];
    expect(times, orderedEquals([...times]..sort()));
    expect(times.any((t) => t.day == 27), isTrue);
    expect((s['texts']! as Map)['taken'], l.alarmTaken);
  });

  test('a dose whose time has just passed is still shown, until answered', () {
    // 14:00: the 13:45 dose is 15 minutes late and still due
    final late = snapshotAt(DateTime.utc(2026, 11, 26, 14));
    expect(wall(entries(late).first), DateTime.utc(2026, 11, 26, 13, 45));
    // Once taken, the widget moves on
    final key = doseKey('napa', DateTime.utc(2026, 11, 26, 13, 45));
    final taken = snapshotAt(DateTime.utc(2026, 11, 26, 14), handled: {key});
    expect(
      wall(entries(taken).first).isAfter(DateTime.utc(2026, 11, 26, 14)),
      isTrue,
    );
  });

  test('"Taken" carries the dose so it can be recorded in the background', () {
    final p = payloadOf(entries(snapshotAt(wallNow)).first);
    expect(p.at, DateTime.utc(2026, 11, 26, 13, 45));
    expect(p.items.single.medicineId, 'napa');
    expect(p.notificationId, isNotNull); // stops the alarm if it is ringing
  });

  test('without medicines the widget says so', () {
    final s = snapshotAt(wallNow, medicines: []);
    expect(entries(s), isEmpty);
    expect((s['texts']! as Map)['empty'], l.widgetNoMedicines);
  });

  test('redraws are scheduled when a dose becomes due and when it is over', () {
    final s = snapshotAt(wallNow);
    final refresh = widgetRefreshTimes(s, now);
    final first = entries(s).first;
    expect(refresh, contains(instant(first['dueFrom'])));
    expect(refresh, contains(instant(first['until'])));
    expect(refresh.every((t) => t.isAfter(now)), isTrue);
    expect(refresh, orderedEquals([...refresh]..sort()));
  });

  group('with the alarm service', () {
    late LocalStore store;
    late FakeWidgetPublisher publisher;
    late AlarmService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = LocalStore(await SharedPreferences.getInstance());
      await store.saveMedicines([napa()]);
      publisher = FakeWidgetPublisher();
      service = AlarmService(
        store: store,
        scheduler: FakeAlarmScheduler(),
        widget: DoseWidget(publisher, l),
        clock: () => DateTime.utc(2026, 11, 26, 8), // 14:00 in Dhaka
      );
    });

    test('every sync redraws the widget', () async {
      await service.sync();
      expect(publisher.publishes, 1);
      expect(
        wall(entries(publisher.snapshot!).first),
        DateTime.utc(2026, 11, 26, 13, 45),
      );
      expect(publisher.refreshAt, isNotEmpty);
    });

    test('"Taken" from the widget records the dose and moves on', () async {
      await service.sync();
      final first = entries(publisher.snapshot!).first;
      await service.record(payloadOf(first), DoseStatus.taken);
      final log = store.logs().single;
      expect(log.medicineId, 'napa');
      expect(log.status, DoseStatus.taken);
      expect(log.scheduledAt, DateTime.utc(2026, 11, 26, 13, 45));
      expect(
        wall(entries(publisher.snapshot!).first),
        isNot(DateTime.utc(2026, 11, 26, 13, 45)),
      );
    });

    test('a widget failure never stops the alarms', () async {
      final scheduler = FakeAlarmScheduler();
      final s = AlarmService(
        store: store,
        scheduler: scheduler,
        widget: DoseWidget(ThrowingPublisher(), l),
        clock: () => now,
      );
      expect(await s.sync(), greaterThan(0));
      expect(scheduler.pending, isNotEmpty);
    });
  });
}
