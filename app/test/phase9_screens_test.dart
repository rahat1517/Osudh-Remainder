import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/alarm_planner.dart';
import 'package:oshudh_reminder/alarms/alarm_scheduler.dart';
import 'package:oshudh_reminder/alarms/alarm_service.dart';
import 'package:oshudh_reminder/alarms/dose_log.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:oshudh_reminder/screens/medicines_screen.dart';
import 'package:oshudh_reminder/screens/ramadan_screen.dart';
import 'package:oshudh_reminder/screens/report_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<(AppState, LocalStore)> stateWith(
  List<MedicineDraft> drafts, {
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = LocalStore(await SharedPreferences.getInstance());
  final now = clock ?? fixedNow;
  final state = AppState(
    auth: DemoAuthRepository(),
    medicines: InMemoryMedicineRepository(now: now),
    api: FakeBackendApi(),
    store: store,
    alarms: AlarmService(
      store: store,
      scheduler: FakeAlarmScheduler(),
      clock: now,
    ),
    clock: now,
  );
  await state.auth.verifyCode('+8801712345678', '123456');
  await state.confirm(drafts, source: 'manual');
  return (state, store);
}

MedicineDraft draft(
  String name,
  String dose, {
  String? generic,
  Timing timing = Timing.notSpecified,
}) {
  final d = MedicineDraft.manual()
    ..name.edit(name)
    ..dose.edit(dose)
    ..timing.edit(timing)
    ..continueIndefinitely = true;
  d.generic = generic;
  return d;
}

Future<void> push(WidgetTester tester, AppState state, Widget screen) async {
  await pumpApp(tester, state);
  Navigator.of(tester.element(find.byType(Scaffold).first))
      .push(MaterialPageRoute<void>(builder: (_) => screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home warns about duplicate ingredients', (tester) async {
    final (state, _) = await stateWith([
      draft('Napa', '1+1+1', generic: 'Paracetamol'),
      draft('Ace', '1+0+1', generic: 'Paracetamol'),
    ]);
    await pumpApp(tester, state);
    expect(find.text('একই ওষুধ দুইবার?'), findsOneWidget);
    expect(find.textContaining('paracetamol'), findsOneWidget);
  });

  testWidgets('accepting a meal-time suggestion moves the meal', (
    tester,
  ) async {
    final (state, store) = await stateWith([draft('Amdocal', '0+0+1')]);
    final id = state.active.single.id;
    for (var d = 23; d <= 25; d++) {
      final scheduled = DateTime.utc(2026, 11, d, 21, 30);
      await store.addLog(
        DoseLog(
          medicineId: id,
          scheduledAt: scheduled,
          status: DoseStatus.taken,
          actedAt: scheduled
              .add(const Duration(minutes: 45))
              .subtract(const Duration(hours: 6)),
        ),
        now: fixedNow(),
      );
    }
    await pumpApp(tester, state);
    expect(find.byKey(const Key('shift-dinner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('acceptShift')));
    await tester.pumpAndSettle();
    expect(state.settings.dinner, 22 * 60 + 15);
    expect(find.byKey(const Key('shift-dinner')), findsNothing);
  });

  testWidgets(
    'before or after food can be changed later, and the alarm moves',
    (tester) async {
      final (state, _) = await stateWith([
        draft('Seclo', '1+0+0', timing: Timing.beforeMeal),
      ]);
      List<DateTime> times() => [
        for (final a in (state.alarms!.scheduler as FakeAlarmScheduler).pending)
          if (!a.isHorizonNotice && a.refillFor == null) a.at,
      ]..sort();
      final before = times();
      await push(tester, state, const MedicinesScreen());
      await tester.tap(find.text('Seclo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editTiming')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timing-afterMeal')));
      await tester.pumpAndSettle();
      expect(state.active.single.timing, Timing.afterMeal);
      expect(find.textContaining('খাবারের পরে'), findsOneWidget);
      expect(find.textContaining('এলার্মও নতুন সময়ে'), findsOneWidget);
      // Before breakfast was 30 min before it; after breakfast is 15 min after
      final after = times();
      expect(after.first.difference(before.first), const Duration(minutes: 45));
    },
  );

  testWidgets('entering tablets on hand shows days left', (tester) async {
    final (state, _) = await stateWith([draft('Seclo', '1+0+1')]);
    await push(tester, state, const MedicinesScreen());
    await tester.tap(find.text('Seclo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editStock')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('stockInput')), '6');
    await tester.tap(find.byKey(const Key('saveStock')));
    await tester.pumpAndSettle();
    expect(state.active.single.pillsOnHand, 6);
    expect(find.textContaining('আর প্রায় ৩ দিন চলবে'), findsOneWidget);
  });

  testWidgets(
    'Ramadan mode applies sehri/iftar times and restores the old ones',
    (tester) async {
      final (state, store) = await stateWith([
        draft('Seclo', '1+0+1', timing: Timing.beforeMeal),
        draft('Napa', '1+1+1', timing: Timing.afterMeal),
      ], clock: () => DateTime.utc(2027, 2, 23, 4));
      final before = state.settings;
      await push(tester, state, const RamadanScreen());
      expect(
        find.textContaining('Napa'),
        findsOneWidget,
      ); // noon dose conflicts with the fast
      await tester.tap(find.byKey(const Key('ramadanToggle')));
      await tester.pumpAndSettle();
      expect(state.settings.breakfast, lessThan(5 * 60));
      expect(state.settings.dinner, greaterThan(18 * 60));
      expect(store.ramadanBackup(), isNotNull);
      await tester.tap(find.byKey(const Key('ramadanToggle')));
      await tester.pumpAndSettle();
      expect(state.settings.breakfast, before.breakfast);
      expect(state.settings.dinner, before.dinner);
      expect(store.ramadanBackup(), isNull);
    },
  );

  test('the adherence report renders as a PDF', () async {
    final (state, _) = await stateWith([draft('Seclo', '1+0+1')]);
    final bytes = await ReportScreen.buildPdf(state, state.weeklyAdherence());
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('refill notices are planned three days before running out', () {
    final m = Medicine(
      id: 'seclo',
      name: 'Seclo',
      dosePattern: '1+0+1',
      pillsOnHand: 20,
      pillsCountedAt: DateTime.utc(2026, 11, 26, 4),
      startAt: DateTime.utc(2026, 11, 20),
    );
    final notices = planRefillNotices(
      medicines: [m],
      settings: const ScheduleSettings(),
      wallNow: DateTime.utc(2026, 11, 26, 10),
    );
    // 20 tablets from 10:00 on the 26th at 2/day: last dose on Dec 6 morning, runs out Dec 6 night → warn Dec 3, 10:00
    expect(notices.single.at, DateTime.utc(2026, 12, 3, 10));
    expect(notices.single.refillFor, 'Seclo');
  });
}
