import 'alarm_payload.dart';
import 'alarm_planner.dart';
import 'alarm_scheduler.dart';
import 'dose_log.dart';
import 'local_store.dart';

const snoozeMinutes = 10;

/// Medicine id of the test alarm from Reminder settings; it is never recorded as a dose.
const testAlarmMedicineId = '__test_alarm__';
const maxSnoozes = 3;

enum SnoozeResult { snoozed, limitReached }

/// Keeps the OS alarms in step with the local medicine list and records what the user does.
class AlarmService {
  AlarmService({
    required this.store,
    required this.scheduler,
    DateTime Function()? clock,
    this.utcOffset = const Duration(hours: 6),
  }) : _clock = clock ?? DateTime.now;

  final LocalStore store;
  final AlarmScheduler scheduler;
  final DateTime Function() _clock;
  final Duration utcOffset;

  DateTime get wallNow {
    final t = _clock().toUtc().add(utcOffset);
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute);
  }

  /// Re-plans and re-schedules every alarm. Returns the number of dose alarms.
  Future<int> sync() async {
    final medicines = store.loadMedicines();
    final settings = store.loadSettings();
    final alarms = planAlarms(
      medicines: medicines,
      settings: settings,
      wallNow: wallNow,
      handledKeys: store.handledKeys(),
      utcOffset: utcOffset,
    );
    final refills = planRefillNotices(
      medicines: medicines,
      settings: settings,
      wallNow: wallNow,
      utcOffset: utcOffset,
    );
    final extras = [
      for (final a in store.extraAlarms())
        if (a.at.isAfter(wallNow)) a,
    ];
    await scheduler.replaceAll([...alarms, ...refills, ...extras]);
    return alarms.where((a) => !a.isNotice).length;
  }

  Future<void> record(AlarmPayload payload, DoseStatus status) async {
    await _dismiss(payload);
    final now = _clock().toUtc();
    for (final item in payload.items) {
      if (item.medicineId == testAlarmMedicineId) continue;
      await store.addLog(
        DoseLog(
          medicineId: item.medicineId,
          scheduledAt: payload.at,
          status: status,
          actedAt: now,
        ),
        now: now,
      );
    }
    await sync();
  }

  /// A real dose alarm about a minute from now, so the user can check that alarms ring on this
  /// phone (locked screen, silent mode, battery saver). Answering it records nothing.
  Future<DateTime> scheduleTestAlarm(String label) async {
    final at = wallNow.add(const Duration(minutes: 1));
    final alarm = AlarmSpec(
      id: stableAlarmId('test|${at.toIso8601String()}'),
      at: at,
      items: [AlarmItem(testAlarmMedicineId, label, '1')],
    );
    await store.addExtraAlarm(alarm, wallNow: wallNow);
    await scheduler.scheduleOne(alarm);
    return at;
  }

  /// Stops the ringing notification once the alarm is answered (in the app or from the
  /// notification); it is "ongoing", so it would otherwise stay in the tray.
  Future<void> _dismiss(AlarmPayload payload) async {
    if (payload.notificationId case final id?) await scheduler.cancel(id);
  }

  Future<SnoozeResult> snooze(AlarmPayload payload) async {
    await _dismiss(payload);
    if (store.snoozeCount(payload.reminderKey) >= maxSnoozes) {
      return SnoozeResult.limitReached;
    }
    final n = await store.incrementSnooze(payload.reminderKey);
    final alarm = AlarmSpec(
      id: stableAlarmId('snooze|${payload.reminderKey}|$n'),
      at: wallNow.add(const Duration(minutes: snoozeMinutes)),
      items: payload.items,
      // Still about the original dose: answering records it, and the snooze limit counts it
      doseAt: payload.at,
    );
    await store.addExtraAlarm(alarm, wallNow: wallNow);
    await scheduler.scheduleOne(alarm);
    return SnoozeResult.snoozed;
  }

  /// Handles a button pressed on a notification (possibly with the app closed).
  Future<void> handleAction(String? actionId, String? rawPayload) async {
    if (rawPayload == null) return;
    final payload = AlarmPayload.decode(rawPayload);
    switch (actionId) {
      case actionTaken:
        await record(payload, DoseStatus.taken);
      case actionSkip:
        await record(payload, DoseStatus.skipped);
      case actionSnooze:
        await snooze(payload);
    }
  }
}
