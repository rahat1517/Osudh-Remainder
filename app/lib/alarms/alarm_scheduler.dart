import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/format.dart';
import '../l10n/generated/app_localizations.dart';
import 'alarm_payload.dart';
import 'alarm_planner.dart';

/// Hands alarms to the operating system.
abstract interface class AlarmScheduler {
  /// Replaces every pending alarm with [alarms].
  Future<void> replaceAll(List<AlarmSpec> alarms);

  /// Schedules one extra alarm (used for snoozing) without touching the others.
  Future<void> scheduleOne(AlarmSpec alarm);
}

const doseChannelId = 'dose_reminders';
const actionTaken = 'taken';
const actionSnooze = 'snooze';
const actionSkip = 'skip';

class NotificationAlarmScheduler implements AlarmScheduler {
  NotificationAlarmScheduler(this._plugin, this._location, this._l10n);

  final FlutterLocalNotificationsPlugin _plugin;
  final tz.Location _location;
  final AppLocalizations _l10n;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> replaceAll(List<AlarmSpec> alarms) async {
    await _plugin.cancelAllPendingNotifications();
    final mode = await _mode();
    for (final a in alarms) {
      await _schedule(a, mode);
    }
  }

  @override
  Future<void> scheduleOne(AlarmSpec alarm) async =>
      _schedule(alarm, await _mode());

  Future<AndroidScheduleMode> _mode() async {
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    return exact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _schedule(AlarmSpec a, AndroidScheduleMode mode) async {
    final when = tz.TZDateTime(
      _location,
      a.at.year,
      a.at.month,
      a.at.day,
      a.at.hour,
      a.at.minute,
    );
    if (a.isNotice) {
      await _plugin.zonedSchedule(
        id: a.id,
        scheduledDate: when,
        title: a.refillFor != null
            ? _l10n.refillNoticeTitle
            : _l10n.horizonNoticeTitle,
        body: a.refillFor != null
            ? _l10n.refillNoticeBody(a.refillFor!)
            : _l10n.horizonNoticeBody,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('app_notices', 'App notices'),
        ),
      );
      return;
    }
    await _plugin.zonedSchedule(
      id: a.id,
      scheduledDate: when,
      title: _l10n.alarmTitle,
      body: a.items
          .map((i) => '${i.label} × ${formatAmount(i.amount)}')
          .join('\n'),
      payload: AlarmPayload.fromSpec(a).encode(),
      androidScheduleMode: mode,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          doseChannelId,
          _l10n.alarmChannelName,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          ongoing: true,
          autoCancel: false,
          actions: [
            AndroidNotificationAction(actionTaken, _l10n.alarmTaken),
            AndroidNotificationAction(actionSnooze, _l10n.alarmSnooze),
            AndroidNotificationAction(actionSkip, _l10n.alarmSkip),
          ],
        ),
      ),
    );
  }
}

/// Records scheduled alarms instead of calling the OS (tests).
class FakeAlarmScheduler implements AlarmScheduler {
  List<AlarmSpec> pending = [];
  final List<AlarmSpec> extra = [];

  @override
  Future<void> replaceAll(List<AlarmSpec> alarms) async =>
      pending = [...alarms];

  @override
  Future<void> scheduleOne(AlarmSpec alarm) async => extra.add(alarm);
}
