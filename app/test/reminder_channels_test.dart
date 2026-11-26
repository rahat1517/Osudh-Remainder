import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/caregivers/caregiver_models.dart';
import 'package:oshudh_reminder/caregivers/caregiver_repository.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/reminder_channels.dart';
import 'package:oshudh_reminder/screens/patient_dashboard_screen.dart';
import 'package:oshudh_reminder/screens/settings_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';

import 'helpers.dart';

void main() {
  late InMemoryReminderChannelsRepository channels;
  late AppState state;

  Future<void> open(WidgetTester tester, Widget screen) async {
    channels = InMemoryReminderChannelsRepository();
    final auth = DemoAuthRepository();
    state = AppState(
      auth: auth,
      medicines: InMemoryMedicineRepository(now: fixedNow),
      api: FakeBackendApi(),
      caregivers: InMemoryCaregiverRepository(
        currentUser: () => auth.currentUserId ?? '',
      ),
      channels: channels,
      clock: fixedNow,
    );
    await auth.verifyCode('+8801712345678', '123456');
    await pumpApp(tester, state);
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    await tester.pumpAndSettle();
  }

  testWidgets('patients opt in to SMS and calls in settings (off by default)', (
    tester,
  ) async {
    await open(tester, const SettingsScreen());
    final me = state.auth.currentUserId!;
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('smsSwitch'))).value,
      isFalse,
    );
    expect(find.byKey(const Key('featurePhoneSwitch')), findsNothing);
    await tester.tap(find.byKey(const Key('smsSwitch')));
    await tester.pumpAndSettle();
    expect(channels.saved[me]?.sms, isTrue);
    expect(channels.saved[me]?.call, isFalse);
  });

  testWidgets('edit caregivers can switch on feature-phone mode', (
    tester,
  ) async {
    const link = CaregiverLink(
      id: 'l',
      patientId: 'mother',
      caregiverId: 'son',
      permission: CaregiverPermission.edit,
    );
    await open(tester, const PatientDashboardScreen(link: link));
    await tester.tap(find.byKey(const Key('featurePhoneSwitch')));
    await tester.pumpAndSettle();
    expect(channels.saved['mother']?.featurePhone, isTrue);
    expect(channels.saved['mother']?.sms, isTrue); // reminders need a channel
  });

  testWidgets('view-only caregivers do not see the switches', (tester) async {
    const link = CaregiverLink(
      id: 'l',
      patientId: 'mother',
      caregiverId: 'son',
      permission: CaregiverPermission.view,
    );
    await open(tester, const PatientDashboardScreen(link: link));
    expect(find.byKey(const Key('featurePhoneSwitch')), findsNothing);
  });
}
