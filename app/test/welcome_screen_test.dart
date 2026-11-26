import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/main.dart';

void main() {
  testWidgets('স্বাগত স্ক্রিনে বাংলা লেখা দেখায়', (tester) async {
    await tester.pumpWidget(const OshudhApp());
    await tester.pumpAndSettle();

    expect(find.text('ওষুধ রিমাইন্ডার'), findsOneWidget);
    expect(find.text('শুরু করুন'), findsOneWidget);
  });

  testWidgets('শুরু করুন চাপলে বার্তা দেখায়', (tester) async {
    await tester.pumpWidget(const OshudhApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('শুরু করুন'));
    await tester.pump();

    expect(find.text('শীঘ্রই আসছে'), findsOneWidget);
  });
}
