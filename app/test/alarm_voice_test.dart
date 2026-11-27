// The recorded voice on the alarm screen: said on opening and repeated until answered, the
// matching reply after a button, and the phone's own voice when a recording is missing.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/alarm_payload.dart';
import 'package:oshudh_reminder/alarms/alarm_planner.dart';
import 'package:oshudh_reminder/alarms/alarm_scheduler.dart';
import 'package:oshudh_reminder/alarms/alarm_service.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/alarms/speaker.dart';
import 'package:oshudh_reminder/alarms/voice.dart';
import 'package:oshudh_reminder/l10n/generated/app_localizations.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:oshudh_reminder/screens/alarm_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlarmService service;
  late FakeAlarmScheduler scheduler;
  late SilentSpeaker speaker;
  late RecordingVoicePlayer voice;

  AlarmPayload payload({String id = 'seclo'}) => AlarmPayload(
    DateTime.utc(2026, 11, 26, 21),
    [AlarmItem(id, 'Seclo 20 mg', '1')],
    notificationId: 77,
  );

  Future<void> open(
    WidgetTester tester, {
    Set<VoiceClip> recorded = const {
      VoiceClip.alarmOpen,
      VoiceClip.taken,
      VoiceClip.snoozed,
    },
    AlarmPayload? p,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    scheduler = FakeAlarmScheduler();
    service = AlarmService(
      store: LocalStore(await SharedPreferences.getInstance()),
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 11, 26, 15),
    );
    speaker = SilentSpeaker();
    voice = RecordingVoicePlayer(available: recorded);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bn'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlarmScreen(
                      payload: p ?? payload(),
                      service: service,
                      speaker: speaker,
                      voice: voice,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'says the recording, stops the ringing notification, repeats until answered',
    (tester) async {
      await open(tester);
      expect(voice.played, [VoiceClip.alarmOpen]);
      expect(scheduler.cancelled, [
        77,
      ]); // the ringing alarm sound stops: the voice takes over
      expect(speaker.spoken, isEmpty); // the phone's robot voice is not needed
      await tester.pump(const Duration(seconds: 5));
      expect(voice.played, [VoiceClip.alarmOpen, VoiceClip.alarmOpen]);
      await tester.tap(find.byKey(const Key('taken')));
      await tester.pumpAndSettle();
      expect(voice.played.last, VoiceClip.taken);
      await tester.pump(const Duration(seconds: 10));
      expect(
        voice.played.where((c) => c == VoiceClip.alarmOpen),
        hasLength(2),
      ); // stopped
    },
  );

  testWidgets('snooze answers with its own recording', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('snooze')));
    await tester.pumpAndSettle();
    expect(voice.played.last, VoiceClip.snoozed);
  });

  testWidgets('a missing recording falls back to the phone voice', (
    tester,
  ) async {
    await open(tester, recorded: const {});
    expect(voice.played, isEmpty);
    expect(speaker.spoken.single, contains('Seclo 20 mg'));
  });

  testWidgets(
    'the test alarm uses the general recording when its own is missing',
    (tester) async {
      await open(tester, p: payload(id: testAlarmMedicineId));
      expect(voice.played, [VoiceClip.alarmOpen]);
    },
  );

  testWidgets(
    'says when to take it, if every medicine due has the same instruction',
    (tester) async {
      final p = AlarmPayload(DateTime.utc(2026, 11, 26, 21), const [
        AlarmItem('seclo', 'Seclo 20 mg', '1', timing: Timing.beforeMeal),
        AlarmItem('pantonix', 'Pantonix 20 mg', '1', timing: Timing.beforeMeal),
      ], notificationId: 78);
      // The timing survives the trip through the notification payload
      final decoded = AlarmPayload.decode(p.encode());
      expect(
        decoded.items.map((i) => i.timing),
        everyElement(Timing.beforeMeal),
      );
      await open(
        tester,
        p: decoded,
        recorded: const {VoiceClip.alarmOpen, VoiceClip.beforeMeal},
      );
      expect(voice.played, [VoiceClip.alarmOpen, VoiceClip.beforeMeal]);
    },
  );

  testWidgets('no timing line when the medicines differ', (tester) async {
    await open(
      tester,
      p: AlarmPayload(DateTime.utc(2026, 11, 26, 21), const [
        AlarmItem('seclo', 'Seclo', '1', timing: Timing.beforeMeal),
        AlarmItem('napa', 'Napa', '1', timing: Timing.afterMeal),
      ]),
      recorded: VoiceClip.values.toSet(),
    );
    expect(voice.played, [VoiceClip.alarmOpen]);
  });
}
