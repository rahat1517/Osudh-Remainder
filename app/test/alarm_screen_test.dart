import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/alarm_payload.dart';
import 'package:oshudh_reminder/alarms/alarm_planner.dart';
import 'package:oshudh_reminder/alarms/alarm_scheduler.dart';
import 'package:oshudh_reminder/alarms/alarm_service.dart';
import 'package:oshudh_reminder/alarms/dose_log.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/alarms/speaker.dart';
import 'package:oshudh_reminder/l10n/generated/app_localizations.dart';
import 'package:oshudh_reminder/screens/alarm_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlarmService service;
  late SilentSpeaker speaker;
  final payload = AlarmPayload(DateTime.utc(2026, 11, 26, 21), const [
    AlarmItem('seclo', 'Seclo 20 mg', '1'),
    AlarmItem('sergel', 'Sergel 20 mg', '1'),
  ]);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    service = AlarmService(
      store: store,
      scheduler: FakeAlarmScheduler(),
      clock: () => DateTime.utc(2026, 11, 26, 15),
    );
    speaker = SilentSpeaker();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bn'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: AlarmScreen(payload: payload, service: service, speaker: speaker),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the medicines and speaks in Bangla', (tester) async {
    await pump(tester);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.text('Seclo 20 mg'), findsOneWidget);
    expect(find.text('Sergel 20 mg'), findsOneWidget);
    expect(
      speaker.spoken.single,
      'এখন আপনার Seclo 20 mg, Sergel 20 mg খাওয়ার সময়।',
    );
  });

  testWidgets('Taken records both doses', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('taken')));
    await tester.pumpAndSettle();
    expect(service.store.logs().map((l) => (l.medicineId, l.status)), [
      ('seclo', DoseStatus.taken),
      ('sergel', DoseStatus.taken),
    ]);
  });

  testWidgets('snoozing a fourth time shows the limit message', (tester) async {
    await pump(tester);
    for (var i = 0; i < maxSnoozes; i++) {
      await service.snooze(payload);
    }
    await tester.tap(find.byKey(const Key('snooze')));
    await tester.pumpAndSettle();
    expect(
      find.text('৩ বার পিছিয়েছেন। এখন খেয়ে নিন অথবা বাদ দিন।'),
      findsOneWidget,
    );
  });
}
