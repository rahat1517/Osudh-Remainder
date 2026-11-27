import 'dart:typed_data';

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

  /// Removes an alarm that is showing (and stops its sound) once the user has answered it.
  Future<void> cancel(int id);
}

/// A channel's sound and importance cannot change once Android has created it, so a new id is
/// needed whenever they change (v2: the phone's alarm tone, repeating, instead of one beep).
const doseChannelId = 'dose_alarms_v2';

/// Android's FLAG_INSISTENT: the sound repeats until the notification is answered or removed.
const _flagInsistent = 4;

/// An alarm stops ringing after this long even if nobody answers (the dose then counts as missed
/// and caregivers are told, see the backend job).
const ringFor = Duration(minutes: 10);
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

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

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
          // Ring like an alarm clock: the phone's alarm tone, on the alarm volume, repeating
          // until answered. One notification beep is easy to miss with the phone in a pocket.
          sound: const UriAndroidNotificationSound(
            'content://settings/system/alarm_alert',
          ),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          additionalFlags: Int32List.fromList([_flagInsistent]),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
          timeoutAfter: ringFor.inMilliseconds,
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
  final List<int> cancelled = [];

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> replaceAll(List<AlarmSpec> alarms) async =>
      pending = [...alarms];

  @override
  Future<void> scheduleOne(AlarmSpec alarm) async => extra.add(alarm);
}
