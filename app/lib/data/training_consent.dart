import 'package:supabase_flutter/supabase_flutter.dart';

/// Opt-in for sharing confirmed prescriptions to improve the reader (Phase 11). Off by default.
abstract interface class TrainingConsentRepository {
  Future<bool> isGranted();

  /// Revoking also deletes shared examples that have not been used yet.
  Future<void> set(bool granted);
}

/// Bump when the consent text changes, so users are asked again.
const trainingConsentVersion = 1;

class SupabaseTrainingConsentRepository implements TrainingConsentRepository {
  SupabaseTrainingConsentRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<bool> isGranted() async {
    final rows = await _db
        .from('training_consents')
        .select('version, revoked_at');
    return rows.isNotEmpty &&
        rows.first['revoked_at'] == null &&
        rows.first['version'] == trainingConsentVersion;
  }

  @override
  Future<void> set(bool granted) => _db.rpc(
    'set_training_consent',
    params: {'granted': granted, 'consent_version': trainingConsentVersion},
  );
}

class InMemoryTrainingConsentRepository implements TrainingConsentRepository {
  bool granted = false;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<void> set(bool value) async => granted = value;
}
