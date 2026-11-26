import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers this device for caregiver alerts (missed-dose push notifications).
abstract interface class PushRegistration {
  Future<void> register();
}

class FirebasePushRegistration implements PushRegistration {
  FirebasePushRegistration(this._db, this._options);

  final SupabaseClient _db;
  final FirebaseOptions _options;
  bool _listening = false;

  Future<void> _store(String token) => _db.from('push_tokens').upsert({
    'token': token,
    'platform': 'android',
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  @override
  Future<void> register() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    // The backend sends through the FCM HTTP v1 API to registration tokens (`message.token`),
    // so we keep the token API here rather than the newer installation-ID registration.
    // ignore: deprecated_member_use
    final token = await messaging.getToken();
    if (token != null) await _store(token);
    if (!_listening) {
      _listening = true;
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen(_store);
    }
  }
}

class NoPushRegistration implements PushRegistration {
  @override
  Future<void> register() async {}
}
