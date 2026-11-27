import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/state/app_state.dart';

import 'helpers.dart';

/// Auth whose session can change outside the sign-in screen (restored, refreshed, expired).
class _ExternalAuth implements AuthRepository {
  final _changes = StreamController<void>.broadcast();
  String? user;

  void set(String? id) {
    user = id;
    _changes.add(null);
  }

  @override
  String? get currentUserId => user;
  @override
  String? get accessToken => user == null ? null : 'token';
  @override
  Stream<void> get changes => _changes.stream;
  @override
  Future<void> sendCode(String phoneE164) async {}
  @override
  Future<void> verifyCode(String phoneE164, String code) async {}
  @override
  Future<void> signOut() async => set(null);
  @override
  Future<void> deleteAccount() async => set(null);
}

void main() {
  test('a session restored after startup shows the app, an expired one the sign-in', () async {
    final auth = _ExternalAuth();
    final state = AppState(
      auth: auth,
      medicines: InMemoryMedicineRepository(now: fixedNow),
      api: FakeBackendApi(),
      clock: fixedNow,
    );
    var notified = 0;
    state.addListener(() => notified++);
    expect(state.signedIn, isFalse);

    auth.set('user-1'); // e.g. the saved session finished restoring
    await pumpEventQueue();
    expect(state.signedIn, isTrue);
    expect(notified, greaterThan(0));

    final before = notified;
    auth.set('user-1'); // token refresh: same user, no rebuild needed
    await pumpEventQueue();
    expect(notified, before);

    auth.set(null); // session expired and could not be refreshed
    await pumpEventQueue();
    expect(state.signedIn, isFalse);
    expect(notified, greaterThan(before));
    state.dispose();
  });
}
