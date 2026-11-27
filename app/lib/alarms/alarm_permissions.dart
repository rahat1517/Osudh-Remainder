import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// What the alarm permissions currently are, and how to ask for them. Wraps the notifications
/// plugin so the screen can be tested.
abstract interface class AlarmPermissions {
  /// null when the phone cannot tell (then the button is always shown).
  Future<bool?> notificationsAllowed();
  Future<bool?> exactAlarmsAllowed();
  Future<bool?> requestNotifications();
  Future<bool?> requestExactAlarms();
  Future<bool?> requestFullScreen();
}

class PluginAlarmPermissions implements AlarmPermissions {
  PluginAlarmPermissions(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  // Resolved on use, not when the screen is built (the platform side may not be ready yet)
  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool?> notificationsAllowed() async =>
      _android?.areNotificationsEnabled();
  @override
  Future<bool?> exactAlarmsAllowed() async =>
      _android?.canScheduleExactNotifications();
  @override
  Future<bool?> requestNotifications() async =>
      _android?.requestNotificationsPermission();
  @override
  Future<bool?> requestExactAlarms() async =>
      _android?.requestExactAlarmsPermission();
  @override
  Future<bool?> requestFullScreen() async =>
      _android?.requestFullScreenIntentPermission();
}
