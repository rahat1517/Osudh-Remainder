import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/dose_log.dart';
import 'package:oshudh_reminder/caregivers/caregiver_models.dart';
import 'package:oshudh_reminder/caregivers/caregiver_repository.dart';
import 'package:oshudh_reminder/caregivers/dashboard.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:oshudh_reminder/screens/family_screen.dart';
import 'package:oshudh_reminder/screens/patient_dashboard_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';

import 'helpers.dart';

Medicine seclo() => Medicine(
  id: 'seclo',
  name: 'Seclo',
  strength: '20 mg',
  dosePattern: '1+0+1',
  timing: Timing.beforeMeal,
  durationDays: 30,
  startAt: DateTime.utc(2026, 11, 25),
);

PatientSnapshot patient({List<DoseLog> logs = const []}) => PatientSnapshot(
  patientId: 'mother',
  name: 'আম্মা',
  settings: const ScheduleSettings(),
  medicines: [seclo()],
  logs: logs,
);

void main() {
  group('todaysDoses', () {
    final morning = DateTime.utc(2026, 11, 26, 7, 30);
    final night = DateTime.utc(2026, 11, 26, 21);

    test('upcoming, due and missed follow the 30-minute grace period', () {
      List<DoseState> at(int h, int m) => todaysDoses(
        patient(),
        DateTime.utc(2026, 11, 26, h, m),
      ).map((r) => r.state).toList();
      expect(at(7, 0), [DoseState.upcoming, DoseState.upcoming]);
      expect(at(7, 45), [DoseState.due, DoseState.upcoming]);
      expect(at(8, 0), [DoseState.missed, DoseState.upcoming]);
    });

    test('taken and skipped come from the dose log', () {
      final rows = todaysDoses(
        patient(
          logs: [
            DoseLog(
              medicineId: 'seclo',
              scheduledAt: morning,
              status: DoseStatus.taken,
              actedAt: DateTime.utc(2026, 11, 26, 1),
            ),
            DoseLog(
              medicineId: 'seclo',
              scheduledAt: night,
              status: DoseStatus.skipped,
              actedAt: DateTime.utc(2026, 11, 26, 15),
            ),
          ],
        ),
        DateTime.utc(2026, 11, 26, 23),
      );
      expect(rows.map((r) => r.state), [DoseState.taken, DoseState.skipped]);
      expect(rows.first.label, 'Seclo 20 mg');
    });
  });

  group('InMemoryCaregiverRepository', () {
    test('invite → accept → link visible to both → revoke', () async {
      var user = 'mother';
      final repo = InMemoryCaregiverRepository(currentUser: () => user);
      final code = await repo.createInvite(CaregiverPermission.edit);
      await expectLater(
        repo.acceptInvite(code),
        throwsA(
          isA<CaregiverException>().having((e) => e.code, 'code', 'invite_own'),
        ),
      );
      user = 'son';
      await repo.acceptInvite(code.toLowerCase());
      expect((await repo.links()).single.permission, CaregiverPermission.edit);
      user = 'mother';
      final link = (await repo.links()).single;
      await repo.revoke(link.id);
      expect(await repo.links(), isEmpty);
      user = 'son';
      await expectLater(
        repo.acceptInvite(code),
        throwsA(isA<CaregiverException>()),
      );
    });
  });

  group('screens', () {
    late InMemoryCaregiverRepository repo;
    late DemoAuthRepository auth;
    late AppState state;

    Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
      auth = DemoAuthRepository();
      repo = InMemoryCaregiverRepository(
        currentUser: () => auth.currentUserId ?? '',
      );
      state = AppState(
        auth: auth,
        medicines: InMemoryMedicineRepository(now: fixedNow),
        api: FakeBackendApi(),
        caregivers: repo,
        clock: fixedNow,
      );
      await state.auth.verifyCode('+8801700000001', '123456');
      await pumpApp(tester, state);
      Navigator.of(tester.element(find.byType(Scaffold).first))
          .push(MaterialPageRoute<void>(builder: (_) => screen));
      await tester.pumpAndSettle();
    }

    testWidgets('patient creates an invite code', (tester) async {
      await pumpScreen(tester, const FamilyScreen());
      await tester.tap(find.text('আমার ওষুধ দেখতে পারবেন'));
      await tester.pumpAndSettle();
      expect(find.text('আমন্ত্রণ কোড'), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byKey(const Key('inviteCode'))).data,
        startsWith('DEMO'),
      );
    });

    testWidgets('a wrong code shows an error; a valid code links the patient', (
      tester,
    ) async {
      await pumpScreen(tester, const FamilyScreen());
      await tester.enterText(find.byKey(const Key('inviteInput')), 'WRONG123');
      await tester.tap(find.byKey(const Key('acceptInvite')));
      await tester.pumpAndSettle();
      expect(
        find.text('কোডটি ভুল, ব্যবহৃত অথবা মেয়াদোত্তীর্ণ।'),
        findsOneWidget,
      );

      // The mother creates a code on her phone; the son (current user) redeems it
      final son = auth.currentUserId!;
      repo.currentUser = () => 'mother';
      final code = await repo.createInvite(CaregiverPermission.view);
      repo.currentUser = () => son;
      await tester.enterText(find.byKey(const Key('inviteInput')), code);
      await tester.tap(find.byKey(const Key('acceptInvite')));
      await tester.pumpAndSettle();
      expect(find.text('পরিবারের সদস্য'), findsOneWidget);
    });

    testWidgets(
      'dashboard shows dose states; view-only caregivers cannot add',
      (tester) async {
        final link = const CaregiverLink(
          id: 'l1',
          patientId: 'mother',
          caregiverId: 'son',
          permission: CaregiverPermission.view,
          patientName: 'আম্মা',
        );
        await pumpScreen(tester, PatientDashboardScreen(link: link));
        repo.patients['mother'] = patient();
        await tester.drag(find.byType(Scrollable).last, const Offset(0, 300));
        await tester.pumpAndSettle();
        // 10:00 Dhaka: the 07:30 dose was missed, 21:00 is upcoming
        expect(find.text('খাওয়া হয়নি'), findsOneWidget);
        expect(find.text('আসছে'), findsOneWidget);
        expect(find.text('তাঁর জন্য প্রেসক্রিপশন যোগ করুন'), findsNothing);
      },
    );
  });
}
