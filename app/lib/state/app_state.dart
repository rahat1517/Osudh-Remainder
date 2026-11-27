import 'dart:async';

import 'package:flutter/foundation.dart';

import '../alarms/alarm_service.dart';
import '../alarms/dose_log_sync.dart';
import '../alarms/local_store.dart';
import '../caregivers/caregiver_repository.dart';
import '../data/auth_repository.dart';
import '../data/backend_api.dart';
import '../data/medicine_draft.dart';
import '../alarms/dose_log.dart';
import '../data/medicine_repository.dart';
import '../data/reminder_channels.dart';
import '../data/training_consent.dart';
import '../insights/insights.dart';
import '../data/models.dart';
import '../schedule/schedule_engine.dart';
import '../schedule/schedule_models.dart';
import '../updates/update_checker.dart';

/// One reminder today: a wall-clock time and the medicines due then.
class TodayReminder {
  const TodayReminder(this.at, this.items);

  final DateTime at; // wall clock (UTC container), see schedule_models.dart
  final List<({Medicine medicine, String amount})> items;
}

class AppState extends ChangeNotifier {
  AppState({
    required this.auth,
    required this.medicines,
    required this.api,
    this.store,
    this.alarms,
    this.caregivers,
    this.channels,
    this.trainingConsent,
    this.updates,
    this.logSync,
    DateTime Function()? clock,
    this.utcOffset = const Duration(hours: 6),
  }) : _clock = clock ?? DateTime.now {
    // React to the session being restored at startup, refreshed or expiring, not only to sign-in
    // from this screen: otherwise a restored session can still show the sign-in screen.
    _wasSignedIn = signedIn;
    _authChanges = auth.changes.listen((_) {
      final now = signedIn;
      if (now == _wasSignedIn) return;
      _wasSignedIn = now;
      notifyListeners();
      if (now) unawaited(refresh().catchError((Object _) {}));
    });
  }

  late final StreamSubscription<void> _authChanges;
  late bool _wasSignedIn;

  @override
  void dispose() {
    _authChanges.cancel();
    super.dispose();
  }

  /// Checks for a newer pilot build; [update] is set when one exists.
  final UpdateChecker? updates;
  AppUpdate? update;

  /// Looks for a newer version once; never throws.
  Future<void> checkForUpdate() async {
    final found = await updates?.check();
    if (found != null) {
      update = found;
      notifyListeners();
    }
  }

  /// Opt-in for sharing confirmed scans (Phase 11).
  final TrainingConsentRepository? trainingConsent;

  /// SMS/call reminder settings (Phase 10).
  final ReminderChannelsRepository? channels;

  /// Caregiver links and patient dashboards (Phase 6).
  final CaregiverRepository? caregivers;

  /// Offline cache; when the server is unreachable the app keeps working from it.
  final LocalStore? store;

  /// Keeps OS alarms in step with [active].
  final AlarmService? alarms;

  /// Uploads the local dose log when online.
  final DoseLogSync? logSync;

  /// True when the last refresh used the offline cache.
  bool offline = false;

  /// Dose alarms scheduled by the last sync.
  int scheduledAlarms = 0;

  final AuthRepository auth;
  final MedicineRepository medicines;
  final BackendApi api;
  final DateTime Function() _clock;

  /// User's fixed UTC offset; Asia/Dhaka has no daylight saving.
  final Duration utcOffset;

  List<Medicine> active = const [];
  ScheduleSettings settings = const ScheduleSettings();
  bool loading = false;

  bool get signedIn => auth.currentUserId != null;

  /// Current wall-clock time in the user's zone.
  DateTime get wallNow {
    final t = _clock().toUtc().add(utcOffset);
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute);
  }

  Future<void> refresh() async {
    if (!signedIn) return;
    loading = true;
    notifyListeners();
    try {
      settings = await medicines.loadSettings();
      active = await medicines.activeMedicines();
      offline = false;
      await store?.saveSettings(settings);
      await store?.saveMedicines(active);
      await _uploadLogs();
    } on Exception {
      final cache = store;
      if (cache == null) rethrow;
      // Offline: keep working from the cache so reminders never stop
      settings = cache.loadSettings();
      active = cache.loadMedicines();
      offline = true;
    } finally {
      scheduledAlarms = await alarms?.sync() ?? 0;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _uploadLogs() async {
    final cache = store;
    final sync = logSync;
    if (cache == null || sync == null) return;
    final pending = cache.unsyncedLogs();
    if (pending.isEmpty) return;
    await cache.markSynced(await sync.upload(pending, utcOffset: utcOffset));
  }

  /// Saves and confirms a prescription. [forUserId] saves it for a patient the user looks after
  /// (edit permission); [scanImage] is shared for training only if the user opted in.
  Future<void> confirm(
    List<MedicineDraft> drafts, {
    required String source,
    String? imageQuality,
    String? forUserId,
    Uint8List? scanImage,
  }) async {
    await medicines.saveConfirmed(
      drafts,
      source: source,
      imageQuality: imageQuality,
      forUserId: forUserId,
    );
    if (forUserId == null) await refresh();
    if (scanImage != null && forUserId == null) {
      await _shareForTraining(scanImage, drafts);
    }
  }

  /// Best effort and only with consent; never blocks or fails the confirmation.
  Future<void> _shareForTraining(
    Uint8List image,
    List<MedicineDraft> drafts,
  ) async {
    final consent = trainingConsent;
    if (consent == null) return;
    try {
      if (!await consent.isGranted()) return;
      await api.submitTrainingExample(image, {
        'medicines': [for (final d in drafts) d.toTrainingLabel()],
      });
    } on Exception {
      // Sharing is optional; ignore failures
    }
  }

  Future<void> stop(String medicineId) async {
    await medicines.stopMedicine(medicineId);
    await refresh();
  }

  /// Dose log on this phone (offline cache).
  List<DoseLog> get doseLogs => store?.logs() ?? const [];

  List<MealShift> mealShiftSuggestions() => suggestMealShifts(
    logs: doseLogs,
    medicines: active,
    settings: settings,
    wallNow: wallNow,
    utcOffset: utcOffset,
  );

  List<({Medicine medicine, RefillStatus status})> lowStock() => [
    for (final m in active)
      if (refillStatus(m, settings, wallNow, utcOffset: utcOffset) case final r?
          when r.needsRefill)
        (medicine: m, status: r),
  ];

  Adherence weeklyAdherence() {
    final now = wallNow;
    return adherence(
      medicines: active,
      logs: doseLogs,
      settings: settings,
      from: now.subtract(const Duration(days: 7)),
      to: now.subtract(const Duration(minutes: 30)),
      utcOffset: utcOffset,
    );
  }

  Future<void> setStock(String medicineId, double pills) async {
    await medicines.updateStock(medicineId, pills);
    await refresh();
  }

  /// Replaces all meal times at once (Ramadan mode on/off).
  Future<void> applySettings(ScheduleSettings updated) async {
    validateSettings(updated);
    await medicines.saveSettings(updated);
    await refresh();
  }

  /// Moves a meal or bed time; reminders tied to it move with it.
  Future<void> updateMealTime(String meal, int minutes) async {
    final s = settings;
    final updated = ScheduleSettings(
      breakfast: meal == 'breakfast' ? minutes : s.breakfast,
      lunch: meal == 'lunch' ? minutes : s.lunch,
      evening: meal == 'evening' ? minutes : s.evening,
      dinner: meal == 'dinner' ? minutes : s.dinner,
      bedtime: meal == 'bedtime' ? minutes : s.bedtime,
    );
    validateSettings(updated); // throws ScheduleException(invalid_meal_times)
    await medicines.saveSettings(updated);
    await refresh();
  }

  Future<void> deleteAccount() async {
    await auth.deleteAccount();
    await _clearLocal();
  }

  Future<void> signOut() async {
    await auth.signOut();
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    await store?.clear();
    active = const [];
    scheduledAlarms = await alarms?.sync() ?? 0;
    notifyListeners();
  }

  /// Today's reminders from midnight to midnight, computed with the schedule engine.
  List<TodayReminder> todaysReminders() {
    final now = wallNow;
    final dayStart = DateTime.utc(now.year, now.month, now.day);
    final byId = {for (final m in active) m.id: m};
    final inputs = [
      for (final m in active) m.toScheduleInput(utcOffset: utcOffset),
    ];
    final occurrences = occurrencesBetween(
      inputs,
      settings,
      dayStart,
      dayStart.add(const Duration(days: 1)),
    );
    return [
      for (final r in groupReminders(occurrences, settings.groupWindowMinutes))
        TodayReminder(r.at, [
          for (final o in r.items)
            (medicine: byId[o.medicineId]!, amount: o.amount),
        ]),
    ];
  }

  TodayReminder? nextReminder() {
    final now = wallNow;
    for (final r in todaysReminders()) {
      if (!r.at.isBefore(now)) return r;
    }
    return null;
  }
}
