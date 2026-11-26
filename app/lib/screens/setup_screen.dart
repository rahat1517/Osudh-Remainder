import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_ui/material_ui.dart';

import '../alarms/battery_guide.dart';
import '../l10n/generated/app_localizations.dart';

const _appPackage = 'com.oshudh.oshudh_reminder';

/// Permissions and battery settings that alarms depend on.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.notifications});

  final FlutterLocalNotificationsPlugin notifications;

  AndroidFlutterLocalNotificationsPlugin? get _android => notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _openBatterySettings() async {
    final info = await DeviceInfoPlugin().androidInfo;
    final guide = batteryGuideFor(info.manufacturer);
    for (final t in guide.targets) {
      try {
        await AndroidIntent(
          componentName: t.component,
          package: t.package,
        ).launch();
        return;
      } on Exception {
        continue; // screen does not exist on this model or ROM version
      }
    }
    try {
      await const AndroidIntent(action: genericBatterySettingsAction).launch();
    } on Exception {
      await const AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$_appPackage',
      ).launch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget step(
      IconData icon,
      String title,
      Future<void> Function() onTap, [
      String? help,
    ]) => Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: help == null ? null : Text(help),
        trailing: FilledButton.tonal(
          onPressed: onTap,
          child: Text(l.setupOpen),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.setupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.setupIntro),
          const SizedBox(height: 12),
          step(Icons.notifications_active, l.setupNotifications, () async {
            await _android?.requestNotificationsPermission();
          }),
          step(Icons.alarm_on, l.setupExactAlarms, () async {
            await _android?.requestExactAlarmsPermission();
          }),
          step(Icons.screen_lock_portrait, l.setupFullScreen, () async {
            await _android?.requestFullScreenIntentPermission();
          }),
          step(
            Icons.battery_saver,
            l.setupBattery,
            _openBatterySettings,
            l.setupBatteryHelp,
          ),
        ],
      ),
    );
  }
}
