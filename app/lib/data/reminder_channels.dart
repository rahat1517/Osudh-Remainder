import 'package:supabase_flutter/supabase_flutter.dart';

/// SMS and voice-call reminder settings for a patient (Phase 10). All off by default.
class ReminderChannels {
  const ReminderChannels({
    this.sms = false,
    this.call = false,
    this.featurePhone = false,
  });

  final bool sms;
  final bool call;

  /// The patient has no smartphone: reminders go out by SMS/call at dose time.
  final bool featurePhone;

  ReminderChannels copyWith({bool? sms, bool? call, bool? featurePhone}) =>
      ReminderChannels(
        sms: sms ?? this.sms,
        call: call ?? this.call,
        featurePhone: featurePhone ?? this.featurePhone,
      );
}

abstract interface class ReminderChannelsRepository {
  Future<ReminderChannels> load(String patientId);

  /// Allowed for the patient and for caregivers with edit permission.
  Future<void> save(String patientId, ReminderChannels channels);
}

class SupabaseReminderChannelsRepository implements ReminderChannelsRepository {
  SupabaseReminderChannelsRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<ReminderChannels> load(String patientId) async {
    final p = await _db
        .from('profiles')
        .select('sms_reminders, call_reminders, feature_phone_mode')
        .eq('id', patientId)
        .single();
    return ReminderChannels(
      sms: p['sms_reminders'] as bool,
      call: p['call_reminders'] as bool,
      featurePhone: p['feature_phone_mode'] as bool,
    );
  }

  @override
  Future<void> save(String patientId, ReminderChannels c) => _db.rpc(
    'set_reminder_channels',
    params: {
      'patient': patientId,
      'sms': c.sms,
      'call': c.call,
      'feature_phone': c.featurePhone,
    },
  );
}

class InMemoryReminderChannelsRepository implements ReminderChannelsRepository {
  final Map<String, ReminderChannels> saved = {};

  @override
  Future<ReminderChannels> load(String patientId) async =>
      saved[patientId] ?? const ReminderChannels();

  @override
  Future<void> save(String patientId, ReminderChannels channels) async =>
      saved[patientId] = channels;
}
