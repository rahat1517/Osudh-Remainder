// Visual tour: renders every screen at a real phone size (720×1604 px, like a common Android
// phone) with the app's own Bangla font and Material icons, and saves PNG screenshots for a person
// to look at. Runs only when SCREENSHOT_DIR is set:
//
//   SCREENSHOT_DIR=/tmp/shots flutter test test/screen_tour_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/alarm_payload.dart';
import 'package:oshudh_reminder/alarms/alarm_planner.dart';
import 'package:oshudh_reminder/alarms/alarm_scheduler.dart';
import 'package:oshudh_reminder/alarms/alarm_service.dart';
import 'package:oshudh_reminder/alarms/dose_log.dart';
import 'package:oshudh_reminder/alarms/local_store.dart';
import 'package:oshudh_reminder/alarms/speaker.dart';
import 'package:oshudh_reminder/alarms/voice.dart';
import 'package:oshudh_reminder/assistant/voice_input.dart';
import 'package:oshudh_reminder/caregivers/caregiver_models.dart';
import 'package:oshudh_reminder/caregivers/caregiver_repository.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/main.dart';
import 'package:oshudh_reminder/screens/alarm_screen.dart';
import 'package:oshudh_reminder/screens/assistant_screen.dart';
import 'package:oshudh_reminder/screens/auth_screens.dart';
import 'package:oshudh_reminder/screens/confirm_screen.dart';
import 'package:oshudh_reminder/screens/family_screen.dart';
import 'package:oshudh_reminder/screens/medicines_screen.dart';
import 'package:oshudh_reminder/screens/patient_dashboard_screen.dart';
import 'package:oshudh_reminder/screens/ramadan_screen.dart';
import 'package:oshudh_reminder/screens/report_screen.dart';
import 'package:oshudh_reminder/screens/scan_screen.dart';
import 'package:oshudh_reminder/screens/settings_screen.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:oshudh_reminder/screens/setup_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

final _out = Platform.environment['SCREENSHOT_DIR'];
final _rootKey = GlobalKey();

Future<void> _loadFonts() async {
  final hind = FontLoader('HindSiliguri');
  for (final w in ['400Regular', '500Medium', '600SemiBold', '700Bold']) {
    hind.addFont(rootBundle.load('assets/fonts/HindSiliguri_$w.ttf'));
  }
  await hind.load();
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
  await loader.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary =
      _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  final error = tester.takeException();
  if (error != null) {
    File('$_out/$name.ERROR.txt').writeAsStringSync('$error');
  }
}

Future<void> _push(WidgetTester tester, Widget screen) async {
  Navigator.of(tester.element(find.byType(Scaffold).first))
      .push(MaterialPageRoute<void>(builder: (_) => screen));
  await tester.pumpAndSettle();
}

Future<void> _pop(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
  await tester.pumpAndSettle();
}

Future<void> _app(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(720, 1604);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  // A new key each time: a fresh navigator, as when the app is opened again
  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: KeyedSubtree(
        key: UniqueKey(),
        child: OshudhApp(state: state),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MedicineDraft _draft(
  String name,
  String dose, {
  String? strength,
  Timing timing = Timing.notSpecified,
  int? days,
  String? generic,
}) {
  final d = MedicineDraft.manual()
    ..name.edit(name)
    ..dose.edit(dose)
    ..timing.edit(timing);
  if (strength != null) d.strength.edit(strength);
  if (days == null) {
    d.continueIndefinitely = true;
  } else {
    d.durationDays.edit(days);
  }
  d.generic = generic;
  return d;
}

void main() {
  setUpAll(() async {
    if (_out == null) return;
    Directory(_out!).createSync(recursive: true);
    await _loadFonts();
  });

  testWidgets('screen tour', skip: _out == null, (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final auth = DemoAuthRepository();
    final state = AppState(
      auth: auth,
      medicines: InMemoryMedicineRepository(now: fixedNow),
      api: FakeBackendApi(),
      store: store,
      alarms: AlarmService(
        store: store,
        scheduler: FakeAlarmScheduler(),
        clock: fixedNow,
      ),
      caregivers: InMemoryCaregiverRepository(
        currentUser: () => auth.currentUserId ?? '',
      ),
      clock: fixedNow,
    );

    // Signed out
    await _app(tester, state);
    await _shot(tester, '01_welcome');
    await _push(tester, const PhoneScreen());
    await _shot(tester, '02_phone');
    await tester.enterText(find.byType(TextField).first, '01712345678');
    await _shot(tester, '03_phone_filled');
    await _push(tester, const OtpScreen(phone: '+8801712345678'));
    await _shot(tester, '04_otp');

    // Signed in, nothing added yet
    await auth.verifyCode('+8801712345678', '123456');
    await state.refresh();
    await _app(tester, state);
    await _shot(tester, '05_home_empty');

    // Realistic data: duplicate paracetamol, a before-meal and a bedtime medicine, low stock
    await state.confirm([
      _draft(
        'Seclo',
        '1+0+1',
        strength: '20 mg',
        timing: Timing.beforeMeal,
        days: 30,
      ),
      _draft(
        'Napa',
        '1+1+1',
        strength: '500 mg',
        timing: Timing.afterMeal,
        days: 5,
        generic: 'Paracetamol',
      ),
      _draft(
        'Ace',
        '1+0+1',
        strength: '500 mg',
        days: 3,
        generic: 'Paracetamol',
      ),
      _draft('Rivotril', '0+0+1', strength: '0.5 mg', timing: Timing.bedtime),
      _draft(
        'Napa Extend Amlodipine Long Name Test',
        '½+0+½',
        strength: '665 mg',
        days: 10,
      ),
    ], source: 'manual');
    await state.setStock(state.active.first.id, 4);
    for (var d = 23; d <= 25; d++) {
      final at = DateTime.utc(2026, 11, d, 21);
      await store.addLog(
        DoseLog(
          medicineId: state.active.first.id,
          scheduledAt: at,
          status: d == 24 ? DoseStatus.skipped : DoseStatus.taken,
          actedAt: at.subtract(const Duration(hours: 6)),
        ),
        now: fixedNow(),
      );
    }
    await state.refresh();
    await _app(tester, state);
    await _shot(tester, '06_home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await _shot(tester, '07_home_scrolled');

    await _push(tester, const ScanScreen());
    await _shot(tester, '08_scan');
    await _pop(tester);

    final scan = PrescriptionScan.fromJson(exampleScanJson());
    await _push(tester, ConfirmScreen.fromScan(scan));
    await _shot(tester, '09_confirm_scan');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await _shot(tester, '10_confirm_scan_scrolled');
    await _pop(tester);

    await _push(tester, ConfirmScreen.manual());
    await _shot(tester, '11_confirm_manual');
    await _pop(tester);

    await _push(tester, const MedicinesScreen());
    await _shot(tester, '12_medicines');
    await tester.tap(find.textContaining('Seclo').first);
    await _shot(tester, '13_medicine_detail');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await _pop(tester);

    await _push(tester, const SettingsScreen());
    await _shot(tester, '14_settings');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await _shot(tester, '15_settings_scrolled');
    await _pop(tester);

    await _push(
      tester,
      SetupScreen(notifications: FlutterLocalNotificationsPlugin()),
    );
    await _shot(tester, '16_reminder_setup');
    await _pop(tester);

    await _push(tester, const ReportScreen());
    await _shot(tester, '17_report');
    await _pop(tester);

    await _push(tester, const RamadanScreen());
    await _shot(tester, '18_ramadan');
    await _pop(tester);

    await _push(tester, const FamilyScreen());
    await _shot(tester, '19_family');
    await _pop(tester);

    await _push(
      tester,
      const PatientDashboardScreen(
        link: CaregiverLink(
          id: 'l',
          patientId: 'mother',
          caregiverId: 'me',
          permission: CaregiverPermission.edit,
        ),
      ),
    );
    await _shot(tester, '20_patient_dashboard');
    await _pop(tester);

    await _push(
      tester,
      AssistantScreen(voice: NoVoiceInput(), speaker: SilentSpeaker()),
    );
    await _shot(tester, '21_assistant');
    await _pop(tester);

    await _push(
      tester,
      AlarmScreen(
        payload: AlarmPayload(DateTime.utc(2026, 11, 26, 21), const [
          AlarmItem('seclo', 'Seclo 20 mg', '1'),
          AlarmItem('napa', 'Napa 500 mg', '1'),
          AlarmItem(
            'long',
            'Napa Extend Amlodipine Long Name Test 665 mg',
            '½',
          ),
        ]),
        service: state.alarms!,
        speaker: SilentSpeaker(),
        voice: RecordingVoicePlayer(),
      ),
    );
    await _shot(tester, '22_alarm');
    File('$_out/state.json')
        .writeAsStringSync(jsonEncode({'active': state.active.length}));
  });
}
