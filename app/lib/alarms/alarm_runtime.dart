/// Process-level alarm setup: notification plugin, time zone, and the background handler that
/// processes alarm buttons while the app is closed.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/generated/app_localizations.dart';
import 'alarm_scheduler.dart';
import 'alarm_service.dart';
import 'local_store.dart';

final notificationsPlugin = FlutterLocalNotificationsPlugin();

const _initSettings = InitializationSettings(
  android: AndroidInitializationSettings('ic_stat_alarm'),
);

Future<AlarmService> createAlarmService(
  LocalStore store, {
  String timezone = 'Asia/Dhaka',
}) async {
  tzdata.initializeTimeZones();
  final location = tz.getLocation(timezone);
  final l10n = lookupAppLocalizations(const Locale('bn'));
  return AlarmService(
    store: store,
    scheduler: NotificationAlarmScheduler(notificationsPlugin, location, l10n),
  );
}

/// Runs in a background isolate when an alarm button is pressed with the app closed.
@pragma('vm:entry-point')
Future<void> onBackgroundAlarmAction(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  await notificationsPlugin.initialize(settings: _initSettings);
  final service = await createAlarmService(await LocalStore.open());
  await service.handleAction(response.actionId, response.payload);
}

/// Initializes notifications. Returns the payload if a dose alarm launched the app.
Future<String?> initNotifications({
  required void Function(NotificationResponse) onResponse,
}) async {
  await notificationsPlugin.initialize(
    settings: _initSettings,
    onDidReceiveNotificationResponse: onResponse,
    onDidReceiveBackgroundNotificationResponse: onBackgroundAlarmAction,
  );
  // Channel used by the server's missed-dose push notifications (see backend notifier)
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        AndroidNotificationChannel(
          'caregiver_alerts',
          lookupAppLocalizations(const Locale('bn')).caregiverAlertsChannel,
          importance: Importance.high,
        ),
      );
  final launch = await notificationsPlugin.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp ?? false) {
    return launch!.notificationResponse?.payload;
  }
  return null;
}
