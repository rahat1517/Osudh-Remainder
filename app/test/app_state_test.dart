import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/alarms/alarm_scheduler.dart';
import 'package:oshudh_reminder/alarms/alarm_service.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:oshudh_reminder/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/models.dart';

import 'helpers.dart';

void main() {
  test('confirming a scan produces today\'s grouped reminders', () async {
    final state = demoState();
    await state.auth.verifyCode('+8801712345678', '123456');
    final scan = PrescriptionScan.fromJson(exampleScanJson());
    final drafts = [for (final m in scan.medicines) MedicineDraft.fromScan(m)];
    for (final d in drafts) {
      for (final f in d.fields) {
        f.markReviewed();
      }
    }
    await state.confirm(drafts, source: 'scan');

    expect(state.active, hasLength(3));
    // Confirmed at 10:00: Seclo and Sergel (before meal) are next at 21:00 tonight; SOS never.
    final today = state.todaysReminders();
    expect(today.map((r) => '${r.at.hour}:${r.at.minute}'), ['21:0']);
    expect(
      today.single.items.map((i) => i.medicine.name),
      unorderedEquals(['Seclo', 'Sergel']),
    );
    expect(state.nextReminder()?.at, today.single.at);
  });

  test('unreviewed drafts cannot be saved', () async {
    final state = demoState();
    await state.auth.verifyCode('+8801712345678', '123456');
    final scan = PrescriptionScan.fromJson(exampleScanJson());
    expect(
      () => state.confirm([
        MedicineDraft.fromScan(scan.medicines[1]),
      ], source: 'scan'),
      throwsStateError,
    );
  });

  test('offline: works from the cache and keeps alarms scheduled', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final scheduler = FakeAlarmScheduler();
    final repo = _FlakyRepository(InMemoryMedicineRepository(now: fixedNow));
    final state = AppState(
      auth: DemoAuthRepository(),
      medicines: repo,
      api: FakeBackendApi(),
      store: store,
      alarms: AlarmService(store: store, scheduler: scheduler, clock: fixedNow),
      clock: fixedNow,
    );
    await state.auth.verifyCode('+8801712345678', '123456');
    final draft = MedicineDraft.manual()
      ..name.edit('Seclo')
      ..dose.edit('1+0+1')
      ..durationDays.edit(30);
    await state.confirm([draft], source: 'manual');
    expect(state.offline, isFalse);
    expect(state.scheduledAlarms, 14);

    repo.down = true;
    await state.refresh();
    expect(state.offline, isTrue);
    expect(state.active.single.name, 'Seclo');
    expect(scheduler.pending.where((a) => !a.isHorizonNotice), hasLength(14));
  });
}

class _FlakyRepository implements MedicineRepository {
  _FlakyRepository(this.inner);

  final MedicineRepository inner;
  bool down = false;

  void _check() {
    if (down) throw Exception('offline');
  }

  @override
  Future<List<Medicine>> activeMedicines() async {
    _check();
    return inner.activeMedicines();
  }

  @override
  Future<ScheduleSettings> loadSettings() async {
    _check();
    return inner.loadSettings();
  }

  @override
  Future<void> saveConfirmed(
    List<MedicineDraft> drafts, {
    required String source,
    String? imageQuality,
    String? forUserId,
  }) => inner.saveConfirmed(
    drafts,
    source: source,
    imageQuality: imageQuality,
    forUserId: forUserId,
  );

  @override
  Future<void> stopMedicine(String id) => inner.stopMedicine(id);

  @override
  Future<void> saveSettings(ScheduleSettings settings) =>
      inner.saveSettings(settings);

  @override
  Future<void> updateStock(String medicineId, double pillsOnHand) =>
      inner.updateStock(medicineId, pillsOnHand);

  @override
  Future<void> updateTiming(String medicineId, Timing timing) =>
      inner.updateTiming(medicineId, timing);
}
