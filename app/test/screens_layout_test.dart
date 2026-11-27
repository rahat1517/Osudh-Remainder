import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/screens/report_screen.dart';
import 'package:oshudh_reminder/screens/setup_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('reminder settings lays out every step with its button', (
    tester,
  ) async {
    // Regression: the theme's full-width buttons inside ListTile.trailing broke the layout and the
    // screen showed up empty in release builds.
    await pumpApp(tester, demoState());
    Navigator.of(tester.element(find.byType(Scaffold).first)).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SetupScreen(notifications: FlutterLocalNotificationsPlugin()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNWidgets(4));
    expect(find.byType(FilledButton), findsNWidgets(4));
  });

  testWidgets('the adherence report screen lays out', (tester) async {
    final state = demoState();
    await state.auth.verifyCode('+8801712345678', '123456');
    final d = MedicineDraft.manual()
      ..name.edit('Seclo')
      ..dose.edit('1+0+1')
      ..continueIndefinitely = true;
    await state.confirm([d], source: 'manual');
    await pumpApp(tester, state);
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute<void>(builder: (_) => const ReportScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(FilledButton), findsOneWidget); // share the PDF
  });
}
