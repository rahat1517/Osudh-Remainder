import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../alarms/alarm_permissions.dart';
import '../alarms/battery_guide.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';

const _appPackage = 'com.oshudh.oshudh_reminder';

/// Permissions and battery settings that alarms depend on. Each step shows whether it is already
/// on: when a permission is granted, Android opens nothing, and a button that seems to do nothing
/// looks broken.
class SetupScreen extends StatefulWidget {
  SetupScreen({
    super.key,
    required FlutterLocalNotificationsPlugin notifications,
    AlarmPermissions? permissions,
  }) : permissions = permissions ?? PluginAlarmPermissions(notifications);

  final AlarmPermissions permissions;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  bool? _notifications;
  bool? _exactAlarms;

  AlarmPermissions get _p => widget.permissions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the phone's settings page: show what changed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final n = await _safe(_p.notificationsAllowed);
    final e = await _safe(_p.exactAlarmsAllowed);
    if (!mounted) return;
    // Alarms set while exact alarms were not allowed were scheduled as inexact (Android may delay
    // them by many minutes): set them again as soon as a permission is turned on
    final improved =
        (e == true && _exactAlarms == false) ||
        (n == true && _notifications == false);
    setState(() {
      _notifications = n;
      _exactAlarms = e;
    });
    if (improved) await context.read<AppState>().refresh();
  }

  Future<void> _testAlarm() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final alarms = context.read<AppState>().alarms;
    if (alarms == null) return;
    await alarms.scheduleTestAlarm(l.testAlarmLabel);
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(l.setupTestAlarmScheduled),
      ),
    );
  }

  static Future<bool?> _safe(Future<bool?> Function() f) async {
    try {
      return await f();
    } on Object {
      return null;
    }
  }

  Future<void> _request(Future<bool?> Function() request) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final granted = await request();
      if (granted ?? false) {
        messenger.showSnackBar(SnackBar(content: Text(l.setupAlreadyOn)));
      }
    } on Object {
      // e.g. another permission request is still open
      messenger.showSnackBar(SnackBar(content: Text(l.setupTryAgain)));
    }
    await _refresh();
  }

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
      Key key,
      IconData icon,
      String title,
      Future<void> Function() onTap, {
      String? help,
      bool? on,
    }) => Card(
      key: key,
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: help == null ? null : Text(help),
        trailing: on ?? false
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(l.setupOn),
                ],
              )
            : FilledButton.tonal(
                // The theme makes buttons full width; in a list row it must size to its label
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
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
          step(
            const Key('setup-notifications'),
            Icons.notifications_active,
            l.setupNotifications,
            () => _request(_p.requestNotifications),
            on: _notifications,
          ),
          step(
            const Key('setup-exact'),
            Icons.alarm_on,
            l.setupExactAlarms,
            () => _request(_p.requestExactAlarms),
            on: _exactAlarms,
          ),
          step(
            const Key('setup-fullscreen'),
            Icons.screen_lock_portrait,
            l.setupFullScreen,
            () => _request(_p.requestFullScreen),
          ),
          step(
            const Key('setup-battery'),
            Icons.battery_saver,
            l.setupBattery,
            _openBatterySettings,
            help: l.setupBatteryHelp,
          ),
          if (context.read<AppState>().alarms != null) ...[
            const SizedBox(height: 16),
            Text(l.setupTestAlarmHelp),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('testAlarm'),
              onPressed: _testAlarm,
              icon: const Icon(Icons.alarm_add),
              label: Text(l.setupTestAlarm),
            ),
          ],
        ],
      ),
    );
  }
}
