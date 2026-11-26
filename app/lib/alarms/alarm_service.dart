import 'alarm_payload.dart';
import 'alarm_planner.dart';
import 'alarm_scheduler.dart';
import 'dose_log.dart';
import 'local_store.dart';

const snoozeMinutes = 10;
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
    final alarms = planAlarms(
      medicines: store.loadMedicines(),
      settings: store.loadSettings(),
      wallNow: wallNow,
      handledKeys: store.handledKeys(),
      utcOffset: utcOffset,
    );
    await scheduler.replaceAll(alarms);
    return alarms.where((a) => !a.isHorizonNotice).length;
  }

  Future<void> record(AlarmPayload payload, DoseStatus status) async {
    final now = _clock().toUtc();
    for (final item in payload.items) {
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

  Future<SnoozeResult> snooze(AlarmPayload payload) async {
    if (store.snoozeCount(payload.reminderKey) >= maxSnoozes) {
      return SnoozeResult.limitReached;
    }
    final n = await store.incrementSnooze(payload.reminderKey);
    await scheduler.scheduleOne(
      AlarmSpec(
        id: stableAlarmId('snooze|${payload.reminderKey}|$n'),
        at: wallNow.add(const Duration(minutes: snoozeMinutes)),
        // The snoozed alarm still refers to the original dose time
        items: payload.items,
      ),
    );
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
