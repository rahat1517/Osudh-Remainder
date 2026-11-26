/// Many Android brands popular in Bangladesh stop background apps aggressively, which silently
/// kills alarms. These are the settings screens where the user can exempt the app.
library;

class SettingsTarget {
  const SettingsTarget(this.package, this.component);

  final String package;
  final String component;
}

class BatteryGuide {
  const BatteryGuide(this.brand, this.targets);

  /// Lower-case brand key, also used to pick localized step-by-step text.
  final String brand;

  /// Brand-specific screens to try in order; the generic battery-optimization list is the fallback.
  final List<SettingsTarget> targets;
}

const genericBatterySettingsAction =
    'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS';

BatteryGuide batteryGuideFor(String manufacturer) {
  final m = manufacturer.toLowerCase();
  if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
    return const BatteryGuide('xiaomi', [
      SettingsTarget(
        'com.miui.securitycenter',
        'com.miui.permcenter.autostart.AutoStartManagementActivity',
      ),
      SettingsTarget(
        'com.miui.powerkeeper',
        'com.miui.powerkeeper.ui.HiddenAppsConfigActivity',
      ),
    ]);
  }
  if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) {
    return const BatteryGuide('oppo', [
      SettingsTarget(
        'com.coloros.safecenter',
        'com.coloros.safecenter.permission.startup.StartupAppListActivity',
      ),
      SettingsTarget(
        'com.coloros.safecenter',
        'com.coloros.safecenter.startupapp.StartupAppListActivity',
      ),
      SettingsTarget(
        'com.oppo.safe',
        'com.oppo.safe.permission.startup.StartupAppListActivity',
      ),
    ]);
  }
  if (m.contains('vivo') || m.contains('iqoo')) {
    return const BatteryGuide('vivo', [
      SettingsTarget(
        'com.vivo.permissionmanager',
        'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
      ),
      SettingsTarget(
        'com.iqoo.secure',
        'com.iqoo.secure.ui.phoneoptimize.BgStartUpManager',
      ),
    ]);
  }
  if (m.contains('samsung')) {
    return const BatteryGuide('samsung', [
      SettingsTarget(
        'com.samsung.android.lool',
        'com.samsung.android.sm.battery.ui.BatteryActivity',
      ),
    ]);
  }
  if (m.contains('huawei') || m.contains('honor')) {
    return const BatteryGuide('huawei', [
      SettingsTarget(
        'com.huawei.systemmanager',
        'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
      ),
    ]);
  }
  // Symphony, Walton, Tecno, Infinix and others: the standard Android screen
  return const BatteryGuide('generic', []);
}
