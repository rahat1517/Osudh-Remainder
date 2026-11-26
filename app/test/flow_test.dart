import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/data/backend_api.dart';
import 'package:oshudh_reminder/screens/scan_screen.dart';
import 'package:provider/provider.dart';
import 'package:oshudh_reminder/state/app_state.dart';

import 'helpers.dart';

Future<void> signIn(WidgetTester tester) async {
  await tester.tap(find.text('শুরু করুন'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('phone')), '01712345678');
  await tester.tap(find.text('কোড পাঠান'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('code')), '123456');
  await tester.tap(find.text('যাচাই করুন'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('welcome screen shows Bangla text by default', (tester) async {
    await pumpApp(tester, demoState());
    expect(find.text('ওষুধ রিমাইন্ডার'), findsOneWidget);
    expect(find.text('শুরু করুন'), findsOneWidget);
  });

  testWidgets('invalid phone numbers are rejected', (tester) async {
    await pumpApp(tester, demoState());
    await tester.tap(find.text('শুরু করুন'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phone')), '12345');
    await tester.tap(find.text('কোড পাঠান'));
    await tester.pumpAndSettle();
    expect(find.text('সঠিক বাংলাদেশি মোবাইল নম্বর দিন'), findsOneWidget);
  });

  testWidgets('wrong one-time code shows an error', (tester) async {
    await pumpApp(tester, demoState());
    await tester.tap(find.text('শুরু করুন'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phone')), '01712345678');
    await tester.tap(find.text('কোড পাঠান'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code')), '000000');
    await tester.tap(find.text('যাচাই করুন'));
    await tester.pumpAndSettle();
    expect(find.text('কোডটি ভুল অথবা মেয়াদ শেষ'), findsOneWidget);
  });

  testWidgets('sign in → scan → review → confirm → reminders on home', (
    tester,
  ) async {
    final state = demoState();
    await pumpApp(tester, state);
    await signIn(tester);
    expect(find.text('আজকের ওষুধ'), findsOneWidget);
    expect(find.textContaining('এখনো কোনো ওষুধ নেই'), findsOneWidget);

    // Scan with a fake camera
    await tester.tap(find.text('প্রেসক্রিপশন স্ক্যান'));
    await tester.pumpAndSettle();
    final scanScreen = tester.widget<ScanScreen>(find.byType(ScanScreen));
    expect(scanScreen.pickImage, isNotNull);
    Navigator.of(tester.element(find.byType(ScanScreen))).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ScanScreen(
          pickImage: ({required bool camera}) async => Uint8List(4),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ছবি তুলুন'));
    await tester.pumpAndSettle();

    // Confirm is disabled while Sergel's name (medium confidence) is unreviewed
    expect(find.text('মিলিয়ে দেখে নিশ্চিত করুন'), findsOneWidget);
    FilledButton confirm() =>
        tester.widget<FilledButton>(find.byKey(const Key('confirm')));
    expect(confirm().onPressed, isNull);
    expect(find.text('হলুদ চিহ্নিত ঘরগুলো মিলিয়ে দেখুন'), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('প্রেসক্রিপশনে লেখা "Sargel"।'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('প্রেসক্রিপশনে লেখা "Sargel"।'), findsOneWidget);
    // Review every highlighted field (Sergel's corrected name, Napa Extend's suggested strength)
    var reviewed = 0;
    for (var attempt = 0; attempt < 30; attempt++) {
      final buttons = find.text('ঠিক আছে', skipOffstage: false);
      if (buttons.evaluate().isEmpty) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pumpAndSettle();
        continue;
      }
      await tester.ensureVisible(buttons.first);
      await tester.pumpAndSettle();
      await tester.tap(buttons.first);
      await tester.pumpAndSettle();
      reviewed++;
    }
    expect(reviewed, 2);
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('confirm')));
    await tester.pumpAndSettle();

    // Back on home: tonight's reminder for both before-meal medicines
    expect(find.text('21:00'), findsOneWidget);
    expect(find.textContaining('Seclo 20 mg × 1'), findsOneWidget);
    expect(find.textContaining('Sergel 20 mg × 1'), findsOneWidget);
    expect(context(tester).active, hasLength(3));
  });

  testWidgets('scan errors are localized and offer manual entry', (
    tester,
  ) async {
    final state = demoState(
      api: FakeBackendApi(error: const ApiException('not_a_prescription')),
    );
    await pumpApp(tester, state);
    await signIn(tester);
    final nav = Navigator.of(tester.element(find.text('আজকের ওষুধ')));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ScanScreen(
          pickImage: ({required bool camera}) async => Uint8List(4),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('গ্যালারি থেকে বেছে নিন'));
    await tester.pumpAndSettle();
    expect(find.text('এটা প্রেসক্রিপশন মনে হচ্ছে না।'), findsOneWidget);
    expect(find.text('নিজে যোগ করুন'), findsOneWidget);
  });

  testWidgets('manual entry requires a valid dose', (tester) async {
    await pumpApp(tester, demoState());
    await signIn(tester);
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'Napa');
    await tester.enterText(find.byKey(const Key('dose')), '10+0+10');
    await tester.enterText(find.byKey(const Key('days')), '5');
    await tester.pumpAndSettle();
    expect(find.text('ডোজ লিখুন, যেমন ১+০+১'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('dose')), '১+১+১');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('confirm'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('account deletion asks for confirmation and signs out', (
    tester,
  ) async {
    await pumpApp(tester, demoState());
    await signIn(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteAccount')));
    await tester.pumpAndSettle();
    expect(find.textContaining('চিরতরে মুছে যাবে'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmDelete')));
    await tester.pumpAndSettle();
    expect(
      find.text('শুরু করুন'),
      findsOneWidget,
    ); // back on the welcome screen
  });
}

AppState context(WidgetTester tester) => Provider.of<AppState>(
  tester.element(find.byType(Scaffold).first),
  listen: false,
);
