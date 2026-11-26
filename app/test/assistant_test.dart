import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/alarms/speaker.dart';
import 'package:oshudh_reminder/assistant/voice_input.dart';
import 'package:oshudh_reminder/data/assistant.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:oshudh_reminder/screens/assistant_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';

import 'helpers.dart';

void main() {
  test('context carries the medicines and meal times', () {
    final ctx = assistantContext(
      medicines: [
        Medicine(
          id: 'seclo',
          name: 'Seclo',
          strength: '20 mg',
          dosePattern: '1+0+1',
          timing: Timing.beforeMeal,
          durationDays: 30,
          startAt: DateTime.utc(2026, 11, 20, 2),
        ),
      ],
      settings: const ScheduleSettings(dinner: 22 * 60),
      now: fixedNow(),
    );
    expect(ctx['settings']['dinner'], '22:00');
    final med = (ctx['medicines'] as List).single as Map;
    expect(med['label'], 'Seclo 20 mg');
    expect(med['timing'], 'before_meal');
    expect(ctx['now'], '2026-11-26T04:00:00.000Z');
  });

  group('AssistantScreen', () {
    late FakeBackendApi api;
    late AppState state;
    late SilentSpeaker speaker;

    Future<void> open(WidgetTester tester, {VoiceInput? voice}) async {
      api = FakeBackendApi();
      speaker = SilentSpeaker();
      state = demoState(api: api);
      await state.auth.verifyCode('+8801712345678', '123456');
      final draft = MedicineDraft.manual()
        ..name.edit('Napa')
        ..dose.edit('1+1+1')
        ..durationDays.edit(5);
      await state.confirm([draft], source: 'manual');
      await pumpApp(tester, state);
      Navigator.of(tester.element(find.byType(Scaffold).first)).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AssistantScreen(voice: voice ?? NoVoiceInput(), speaker: speaker),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> ask(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('question')), text);
      await tester.tap(find.byKey(const Key('send')));
      await tester.pumpAndSettle();
    }

    testWidgets('answers, reads the reply aloud, and sends context', (
      tester,
    ) async {
      await open(tester);
      api.assistantReplies.add(
        const AssistantReply('পরের ওষুধ দুপুর ১:৪৫-এ।', [], null),
      );
      await ask(tester, 'পরের ওষুধ কখন?');
      expect(find.text('পরের ওষুধ কখন?'), findsOneWidget);
      expect(find.text('পরের ওষুধ দুপুর ১:৪৫-এ।'), findsOneWidget);
      expect(speaker.spoken.single, 'পরের ওষুধ দুপুর ১:৪৫-এ।');
      expect(
        (api.assistantContexts.single['medicines'] as List).single['label'],
        'Napa',
      );
    });

    testWidgets('a proposed stop is applied only after Confirm', (
      tester,
    ) async {
      await open(tester);
      final id = state.active.single.id;
      api.assistantReplies.add(
        AssistantReply('স্ক্রিনে নিশ্চিত করুন।', [
          AssistantAction(
            type: AssistantActionType.stopMedicine,
            medicineId: id,
          ),
        ], null),
      );
      await ask(tester, 'ডাক্তার নাপা বন্ধ করতে বলেছেন');
      expect(find.text('Napa-এর রিমাইন্ডার বন্ধ করবেন?'), findsOneWidget);
      expect(state.active, hasLength(1)); // nothing changed yet
      await tester.tap(find.byKey(const Key('confirmAction')));
      await tester.pumpAndSettle();
      expect(state.active, isEmpty);
      expect(find.text('হয়ে গেছে'), findsOneWidget);
    });

    testWidgets('a proposed meal-time change updates settings after Confirm', (
      tester,
    ) async {
      await open(tester);
      api.assistantReplies.add(
        const AssistantReply('নিশ্চিত করুন।', [
          AssistantAction(
            type: AssistantActionType.changeMealTime,
            meal: 'dinner',
            time: '22:30',
          ),
        ], null),
      );
      await ask(tester, 'আমি রাতে সাড়ে দশটায় খাই');
      expect(find.text('রাতের খাবার-এর সময় 22:30 করবেন?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmAction')));
      await tester.pumpAndSettle();
      expect(state.settings.dinner, 22 * 60 + 30);
    });

    testWidgets('emergencies show a call button', (tester) async {
      await open(tester);
      api.assistantReplies.add(
        const AssistantReply('এখনই ৯৯৯ নম্বরে ফোন করুন।', [], 'cardiac'),
      );
      await ask(tester, 'বুকে ব্যথা');
      expect(find.byKey(const Key('call999')), findsOneWidget);
    });

    testWidgets('voice unavailable shows a message', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('mic')));
      await tester.pumpAndSettle();
      expect(
        find.text('এই ফোনে কথা বলে প্রশ্ন করা যাচ্ছে না।'),
        findsOneWidget,
      );
    });
  });
}
