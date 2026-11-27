import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepository {
  String? get currentUserId;

  /// Bearer token for backend calls.
  String? get accessToken;

  /// Fires when the user signs in or out, or the saved session is restored or expires.
  Stream<void> get changes;

  Future<void> sendCode(String phoneE164);

  /// Throws [AuthException] with code `invalid_code` on a wrong or expired code.
  Future<void> verifyCode(String phoneE164, String code);

  Future<void> signOut();

  /// Permanently deletes the account and all its data, then signs out.
  Future<void> deleteAccount();
}

class AuthException implements Exception {
  const AuthException(this.code);

  final String code; // invalid_code, sms_failed, network_error

  @override
  String toString() => 'AuthException($code)';
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get accessToken => _client.auth.currentSession?.accessToken;

  @override
  Stream<void> get changes => _client.auth.onAuthStateChange.map((_) {});

  @override
  Future<void> sendCode(String phoneE164) async {
    try {
      await _client.auth.signInWithOtp(phone: phoneE164);
    } on Exception {
      throw const AuthException('sms_failed');
    }
  }

  @override
  Future<void> verifyCode(String phoneE164, String code) async {
    try {
      await _client.auth.verifyOTP(
        phone: phoneE164,
        token: code,
        type: OtpType.sms,
      );
    } on Exception {
      throw const AuthException('invalid_code');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    await _client.rpc('delete_my_account');
    await _client.auth.signOut();
  }
}

/// Development-only authentication: any valid number, code 123456.
class DemoAuthRepository implements AuthRepository {
  static const demoCode = '123456';
  String? _user;

  @override
  String? get currentUserId => _user;

  @override
  String? get accessToken => null;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> sendCode(String phoneE164) async {}

  @override
  Future<void> verifyCode(String phoneE164, String code) async {
    if (code != demoCode) throw const AuthException('invalid_code');
    _user = 'demo-$phoneE164';
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> deleteAccount() => signOut();
}
