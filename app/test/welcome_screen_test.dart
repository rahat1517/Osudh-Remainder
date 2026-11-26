import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/main.dart';

void main() {
  testWidgets('welcome screen shows Bangla text by default', (tester) async {
    await tester.pumpWidget(const OshudhApp());
    await tester.pumpAndSettle();

    expect(find.text('ওষুধ রিমাইন্ডার'), findsOneWidget);
    expect(find.text('শুরু করুন'), findsOneWidget);
  });

  testWidgets('tapping Get started shows a message', (tester) async {
    await tester.pumpWidget(const OshudhApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('শুরু করুন'));
    await tester.pump();

    expect(find.text('শীঘ্রই আসছে'), findsOneWidget);
  });
}
