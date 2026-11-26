// Regression test: a caregiver's prescription must be saved for the patient, not the caregiver.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/caregivers/caregiver_models.dart';
import 'package:oshudh_reminder/caregivers/caregiver_repository.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/screens/patient_dashboard_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';

import 'helpers.dart';
import 'training_consent_test.dart' show RecordingRepository;

void main() {
  test('confirm(forUserId) saves for the patient and leaves the caregiver\'s list alone', () async {
    final repo = RecordingRepository();
    final state = AppState(
      auth: DemoAuthRepository(),
      medicines: repo,
      api: FakeBackendApi(),
      clock: fixedNow,
    );
    await state.auth.verifyCode('+8801712345678', '123456');
    final d = MedicineDraft.manual()
      ..name.edit('Napa')
      ..dose.edit('1+1+1')
      ..durationDays.edit(5);
    await state.confirm([d], source: 'manual', forUserId: 'mother');
    expect(repo.savedFor, ['mother']);
    expect(state.active, isEmpty);
  });

  testWidgets('adding from the patient dashboard saves for the patient', (
    tester,
  ) async {
    final repo = RecordingRepository();
    final auth = DemoAuthRepository();
    final state = AppState(
      auth: auth,
      medicines: repo,
      api: FakeBackendApi(),
      caregivers: InMemoryCaregiverRepository(
        currentUser: () => auth.currentUserId ?? '',
      ),
      clock: fixedNow,
    );
    await auth.verifyCode('+8801712345678', '123456');
    await pumpApp(tester, state);
    const link = CaregiverLink(
      id: 'l',
      patientId: 'mother',
      caregiverId: 'son',
      permission: CaregiverPermission.edit,
    );
    Navigator.of(tester.element(find.byType(Scaffold).first)).push(
      MaterialPageRoute<void>(
        builder: (_) => const PatientDashboardScreen(link: link),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('তাঁর জন্য প্রেসক্রিপশন যোগ করুন'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'Napa');
    await tester.enterText(find.byKey(const Key('dose')), '1+1+1');
    await tester.enterText(find.byKey(const Key('days')), '5');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm')));
    await tester.pumpAndSettle();
    expect(repo.savedFor, ['mother']);
    expect(
      find.byType(PatientDashboardScreen),
      findsOneWidget,
    ); // returned to the dashboard
  });
}
