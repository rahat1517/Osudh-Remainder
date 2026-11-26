/// Offline cache on the phone: medicines, settings, dose log and snooze counts.
///
/// Backed by SharedPreferences so it is also usable from the background isolate that handles
/// alarm buttons while the app is closed.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../schedule/schedule_models.dart';
import 'dose_log.dart';

class LocalStore {
  LocalStore(this._prefs);

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _medicinesKey = 'medicines_v1';
  static const _settingsKey = 'settings_v1';
  static const _logsKey = 'dose_logs_v1';
  static const _snoozeKey = 'snoozes_v1';

  /// Logs older than this are pruned once synced.
  static const logRetention = Duration(days: 90);

  Future<void> saveMedicines(List<Medicine> medicines) => _prefs.setString(
    _medicinesKey,
    jsonEncode([for (final m in medicines) m.toJson()]),
  );

  List<Medicine> loadMedicines() {
    final raw = _prefs.getString(_medicinesKey);
    if (raw == null) return const [];
    return [
      for (final j in jsonDecode(raw) as List)
        Medicine.fromJson(j as Map<String, dynamic>),
    ];
  }

  Future<void> saveSettings(ScheduleSettings s) => _prefs.setString(
    _settingsKey,
    jsonEncode({
      'breakfast': s.breakfast,
      'lunch': s.lunch,
      'evening': s.evening,
      'dinner': s.dinner,
      'bedtime': s.bedtime,
    }),
  );

  ScheduleSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return const ScheduleSettings();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return ScheduleSettings(
      breakfast: j['breakfast'] as int,
      lunch: j['lunch'] as int,
      evening: j['evening'] as int,
      dinner: j['dinner'] as int,
      bedtime: j['bedtime'] as int,
    );
  }

  List<DoseLog> logs() {
    final raw = _prefs.getString(_logsKey);
    if (raw == null) return const [];
    return [
      for (final j in jsonDecode(raw) as List)
        DoseLog.fromJson(j as Map<String, dynamic>),
    ];
  }

  Future<void> _saveLogs(List<DoseLog> logs) => _prefs.setString(
    _logsKey,
    jsonEncode([for (final l in logs) l.toJson()]),
  );

  /// Records an action; a later action on the same dose replaces the earlier one.
  Future<void> addLog(DoseLog log, {DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(logRetention);
    final kept = <DoseLog>[
      for (final l in logs())
        if (l.key != log.key && !(l.synced && l.actedAt.isBefore(cutoff))) l,
      log,
    ];
    await _saveLogs(kept);
  }

  Set<String> handledKeys() => {for (final l in logs()) l.key};

  List<DoseLog> unsyncedLogs() => [
    for (final l in logs())
      if (!l.synced) l,
  ];

  Future<void> markSynced(Iterable<String> keys) async {
    final done = keys.toSet();
    await _saveLogs([
      for (final l in logs()) done.contains(l.key) ? l.markSynced() : l,
    ]);
  }

  Map<String, int> _snoozes() {
    final raw = _prefs.getString(_snoozeKey);
    return raw == null ? {} : (jsonDecode(raw) as Map).cast<String, int>();
  }

  int snoozeCount(String reminderKey) => _snoozes()[reminderKey] ?? 0;

  Future<int> incrementSnooze(String reminderKey) async {
    final all = _snoozes();
    final n = (all[reminderKey] ?? 0) + 1;
    all[reminderKey] = n;
    await _prefs.setString(_snoozeKey, jsonEncode(all));
    return n;
  }

  Future<void> clear() => _prefs.clear();
}
