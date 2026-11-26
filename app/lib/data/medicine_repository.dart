import 'package:supabase_flutter/supabase_flutter.dart';

import '../schedule/schedule_models.dart';
import 'medicine_draft.dart';
import 'models.dart';

abstract interface class MedicineRepository {
  /// Medicines of confirmed prescriptions that are not stopped.
  Future<List<Medicine>> activeMedicines();

  /// Saves the drafts as one prescription and confirms it. Every draft must be [MedicineDraft.isReady].
  Future<void> saveConfirmed(
    List<MedicineDraft> drafts, {
    required String source,
    String? imageQuality,
  });

  Future<void> stopMedicine(String id);

  Future<ScheduleSettings> loadSettings();

  /// Saves the user's meal and bed times.
  Future<void> saveSettings(ScheduleSettings settings);

  /// Records how many tablets (doses) the user has now, for refill reminders.
  Future<void> updateStock(String medicineId, double pillsOnHand);
}

void _checkReady(List<MedicineDraft> drafts) {
  if (drafts.isEmpty || drafts.any((d) => !d.isReady)) {
    throw StateError('Only fully reviewed, valid medicines can be confirmed');
  }
}

int _clock(String hhmmss) {
  final p = hhmmss.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

class SupabaseMedicineRepository implements MedicineRepository {
  SupabaseMedicineRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Medicine>> activeMedicines() async {
    final rows = await _db
        .from('active_medicines')
        .select()
        .order('created_at');
    return [for (final r in rows) Medicine.fromJson(r)];
  }

  @override
  Future<void> saveConfirmed(
    List<MedicineDraft> drafts, {
    required String source,
    String? imageQuality,
  }) async {
    _checkReady(drafts);
    final prescription = await _db
        .from('prescriptions')
        .insert({'source': source, 'image_quality': imageQuality})
        .select('id')
        .single();
    final id = prescription['id'] as String;
    await _db.from('medicines').insert([
      for (final d in drafts) d.toRow(prescriptionId: id),
    ]);
    await _db.rpc('confirm_prescription', params: {'prescription': id});
  }

  @override
  Future<void> stopMedicine(String id) => _db
      .from('medicines')
      .update({'stopped_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);

  @override
  Future<void> updateStock(String medicineId, double pillsOnHand) => _db
      .from('medicines')
      .update({
        'pills_on_hand': pillsOnHand,
        'pills_counted_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', medicineId);

  @override
  Future<void> saveSettings(ScheduleSettings s) async {
    String t(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    final userId = _db.auth.currentUser!.id;
    await _db
        .from('profiles')
        .update({
          'breakfast': t(s.breakfast),
          'lunch': t(s.lunch),
          'evening': t(s.evening),
          'dinner': t(s.dinner),
          'bedtime': t(s.bedtime),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  @override
  Future<ScheduleSettings> loadSettings() async {
    final p = await _db
        .from('profiles')
        .select()
        .eq('id', _db.auth.currentUser!.id)
        .single();
    return ScheduleSettings(
      breakfast: _clock(p['breakfast'] as String),
      lunch: _clock(p['lunch'] as String),
      evening: _clock(p['evening'] as String),
      dinner: _clock(p['dinner'] as String),
      bedtime: _clock(p['bedtime'] as String),
    );
  }
}

/// In-memory repository for demo mode and tests.
class InMemoryMedicineRepository implements MedicineRepository {
  InMemoryMedicineRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<Medicine> _medicines = [];
  var _nextId = 1;
  ScheduleSettings settings = const ScheduleSettings();

  @override
  Future<List<Medicine>> activeMedicines() async =>
      List.unmodifiable(_medicines);

  @override
  Future<void> saveConfirmed(
    List<MedicineDraft> drafts, {
    required String source,
    String? imageQuality,
    String? forUserId,
  }) async {
    _checkReady(drafts);
    final start = _now();
    for (final d in drafts) {
      final row = d.toRow(prescriptionId: 'local');
      _medicines.add(
        Medicine(
          id: 'm${_nextId++}',
          name: row['name'] as String,
          strength: row['strength'] as String?,
          form: row['form'] as String?,
          drugId: row['drug_id'] as int?,
          generic: row['generic'] as String?,
          dosePattern: row['dose_pattern'] as String?,
          timing: timingFromJson(row['timing'] as String),
          durationDays: row['duration_days'] as int?,
          asNeeded: row['as_needed'] as bool,
          startAt: start,
        ),
      );
    }
  }

  @override
  Future<void> stopMedicine(String id) async =>
      _medicines.removeWhere((m) => m.id == id);

  @override
  Future<ScheduleSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(ScheduleSettings s) async => settings = s;

  @override
  Future<void> updateStock(String medicineId, double pillsOnHand) async {
    final i = _medicines.indexWhere((m) => m.id == medicineId);
    if (i < 0) return;
    final m = _medicines[i];
    _medicines[i] = Medicine(
      id: m.id,
      name: m.name,
      strength: m.strength,
      form: m.form,
      drugId: m.drugId,
      dosePattern: m.dosePattern,
      intervalHours: m.intervalHours,
      timing: m.timing,
      durationDays: m.durationDays,
      weekdays: m.weekdays,
      asNeeded: m.asNeeded,
      startAt: m.startAt,
      generic: m.generic,
      pillsOnHand: pillsOnHand,
      pillsCountedAt: _now(),
    );
  }
}
