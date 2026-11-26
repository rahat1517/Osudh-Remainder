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
  Future<ScheduleSettings> loadSettings() async {
    final p = await _db.from('profiles').select().single();
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
}
