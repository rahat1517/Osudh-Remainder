// New users start at once, without a phone number or SMS code (free for everyone).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/screens/settings_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('শুরু করুন opens the app without a phone number', (tester) async {
    final state = demoState();
    await pumpApp(tester, state);
    await tester.tap(find.byKey(const Key('start')));
    await tester.pumpAndSettle();
    expect(state.signedIn, isTrue);
    expect(state.isAnonymous, isTrue);
    expect(find.text('আজকের ওষুধ'), findsOneWidget); // home
  });

  testWidgets('phone sign-in is still offered', (tester) async {
    await pumpApp(tester, demoState());
    await tester.tap(find.byKey(const Key('phoneSignIn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone')), findsOneWidget);
  });

  testWidgets('signing out without a phone number warns first', (tester) async {
    final state = demoState();
    await pumpApp(tester, state);
    await tester.tap(find.byKey(const Key('start')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    await tester.pumpAndSettle();
    final signOut = find.text('সাইন আউট');
    await tester.scrollUntilVisible(
      signOut,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(find.textContaining('আর ফেরত পাওয়া যাবে না'), findsOneWidget);
    await tester.tap(find.text('বাতিল'));
    await tester.pumpAndSettle();
    expect(state.signedIn, isTrue); // cancelled: still signed in
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSignOut')));
    await tester.pumpAndSettle();
    expect(state.signedIn, isFalse);
  });
}
