import 'package:supabase_flutter/supabase_flutter.dart';

import '../alarms/dose_log.dart';
import '../data/models.dart';
import '../schedule/schedule_models.dart';
import 'caregiver_models.dart';

abstract interface class CaregiverRepository {
  /// Creates a single-use invite code (valid 24 hours).
  Future<String> createInvite(CaregiverPermission permission);

  /// Throws [CaregiverException] (`invite_invalid`, `invite_own`).
  Future<void> acceptInvite(String code);

  /// Links where the current user is the patient or the caregiver.
  Future<List<CaregiverLink>> links();

  Future<void> revoke(String linkId);

  Future<PatientSnapshot> patient(String patientId, {required DateTime since});
}

int _clock(String hhmmss) {
  final p = hhmmss.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

class SupabaseCaregiverRepository implements CaregiverRepository {
  SupabaseCaregiverRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<String> createInvite(CaregiverPermission permission) async =>
      await _db.rpc(
        'create_caregiver_invite',
        params: {'permission': permission.name},
      ) as String;

  @override
  Future<void> acceptInvite(String code) async {
    try {
      await _db.rpc('accept_caregiver_invite', params: {'invite_code': code});
    } on PostgrestException catch (e) {
      throw CaregiverException(
        e.message.contains('invite_own') ? 'invite_own' : 'invite_invalid',
      );
    }
  }

  @override
  Future<List<CaregiverLink>> links() async {
    final rows = await _db
        .from('caregiver_links')
        .select()
        .eq('status', 'active');
    final ids = {
      for (final r in rows) ...[
        r['patient_id'] as String,
        r['caregiver_id'] as String,
      ],
    };
    final profiles = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _db
              .from('profiles')
              .select('id, display_name')
              .inFilter('id', ids.toList());
    final names = {
      for (final p in profiles) p['id'] as String: p['display_name'] as String?,
    };
    return [
      for (final r in rows)
        CaregiverLink(
          id: r['id'] as String,
          patientId: r['patient_id'] as String,
          caregiverId: r['caregiver_id'] as String,
          permission: CaregiverPermission.values.byName(
            r['permission'] as String,
          ),
          patientName: names[r['patient_id']],
          caregiverName: names[r['caregiver_id']],
        ),
    ];
  }

  @override
  Future<void> revoke(String linkId) =>
      _db.rpc('revoke_caregiver_link', params: {'link': linkId});

  @override
  Future<PatientSnapshot> patient(
    String patientId, {
    required DateTime since,
  }) async {
    final profile = await _db
        .from('profiles')
        .select()
        .eq('id', patientId)
        .single();
    final meds = await _db
        .from('active_medicines')
        .select()
        .eq('user_id', patientId);
    final logs = await _db
        .from('dose_logs')
        .select()
        .eq('user_id', patientId)
        .gte('scheduled_at', since.toUtc().toIso8601String());
    return PatientSnapshot(
      patientId: patientId,
      name: profile['display_name'] as String?,
      settings: ScheduleSettings(
        breakfast: _clock(profile['breakfast'] as String),
        lunch: _clock(profile['lunch'] as String),
        evening: _clock(profile['evening'] as String),
        dinner: _clock(profile['dinner'] as String),
        bedtime: _clock(profile['bedtime'] as String),
      ),
      medicines: [for (final m in meds) Medicine.fromJson(m)],
      logs: [
        for (final l in logs)
          DoseLog(
            medicineId: l['medicine_id'] as String,
            // instant → Dhaka wall clock
            scheduledAt: DateTime.parse(l['scheduled_at'] as String)
                .toUtc()
                .add(const Duration(hours: 6)),
            status: DoseStatus.values.byName(l['status'] as String),
            actedAt: DateTime.parse(l['acted_at'] as String),
            synced: true,
          ),
      ],
    );
  }
}

/// Demo-mode repository: invites and links between two simulated accounts.
class InMemoryCaregiverRepository implements CaregiverRepository {
  InMemoryCaregiverRepository({required this.currentUser});

  String Function() currentUser;
  final Map<String, (String patient, CaregiverPermission permission)> _invites =
      {};
  final List<CaregiverLink> _links = [];
  final Map<String, PatientSnapshot> patients = {};
  var _next = 0;

  @override
  Future<String> createInvite(CaregiverPermission permission) async {
    final code = 'DEMO${(1000 + _next++).toString()}';
    _invites[code] = (currentUser(), permission);
    return code;
  }

  @override
  Future<void> acceptInvite(String code) async {
    final invite = _invites.remove(code.trim().toUpperCase());
    if (invite == null) throw const CaregiverException('invite_invalid');
    if (invite.$1 == currentUser()) {
      _invites[code] = invite;
      throw const CaregiverException('invite_own');
    }
    _links.add(
      CaregiverLink(
        id: 'l${_next++}',
        patientId: invite.$1,
        caregiverId: currentUser(),
        permission: invite.$2,
      ),
    );
  }

  @override
  Future<List<CaregiverLink>> links() async => [
    for (final l in _links)
      if (l.patientId == currentUser() || l.caregiverId == currentUser()) l,
  ];

  @override
  Future<void> revoke(String linkId) async =>
      _links.removeWhere((l) => l.id == linkId);

  @override
  Future<PatientSnapshot> patient(
    String patientId, {
    required DateTime since,
  }) async =>
      patients[patientId] ??
      PatientSnapshot(
        patientId: patientId,
        name: null,
        settings: const ScheduleSettings(),
        medicines: const [],
        logs: const [],
      );
}
