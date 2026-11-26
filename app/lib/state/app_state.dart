import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/backend_api.dart';
import '../data/medicine_draft.dart';
import '../data/medicine_repository.dart';
import '../data/models.dart';
import '../schedule/schedule_engine.dart';
import '../schedule/schedule_models.dart';

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
    DateTime Function()? clock,
    this.utcOffset = const Duration(hours: 6),
  }) : _clock = clock ?? DateTime.now;

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
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> confirm(
    List<MedicineDraft> drafts, {
    required String source,
    String? imageQuality,
  }) async {
    await medicines.saveConfirmed(
      drafts,
      source: source,
      imageQuality: imageQuality,
    );
    await refresh();
  }

  Future<void> stop(String medicineId) async {
    await medicines.stopMedicine(medicineId);
    await refresh();
  }

  Future<void> signOut() async {
    await auth.signOut();
    active = const [];
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
