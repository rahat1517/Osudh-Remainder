import 'package:supabase_flutter/supabase_flutter.dart';

import 'dose_log.dart';

abstract interface class DoseLogSync {
  /// Uploads logs; returns the keys that were stored.
  Future<List<String>> upload(List<DoseLog> logs, {Duration utcOffset});
}

class SupabaseDoseLogSync implements DoseLogSync {
  SupabaseDoseLogSync(this._db);

  final SupabaseClient _db;

  @override
  Future<List<String>> upload(
    List<DoseLog> logs, {
    Duration utcOffset = const Duration(hours: 6),
  }) async {
    if (logs.isEmpty) return const [];
    await _db.from('dose_logs').upsert([
      for (final l in logs)
        {
          'medicine_id': l.medicineId,
          // Wall clock → instant
          'scheduled_at': l.scheduledAt.subtract(utcOffset).toIso8601String(),
          'status': l.status.name,
          'acted_at': l.actedAt.toUtc().toIso8601String(),
        },
    ], onConflict: 'medicine_id,scheduled_at');
    return [for (final l in logs) l.key];
  }
}
