import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/models.dart';

import 'helpers.dart';

void main() {
  test('confirming a scan produces today\'s grouped reminders', () async {
    final state = demoState();
    await state.auth.verifyCode('+8801712345678', '123456');
    final scan = PrescriptionScan.fromJson(exampleScanJson());
    final drafts = [for (final m in scan.medicines) MedicineDraft.fromScan(m)];
    for (final d in drafts) {
      for (final f in d.fields) {
        f.markReviewed();
      }
    }
    await state.confirm(drafts, source: 'scan');

    expect(state.active, hasLength(3));
    // Confirmed at 10:00: Seclo and Sergel (before meal) are next at 21:00 tonight; SOS never.
    final today = state.todaysReminders();
    expect(today.map((r) => '${r.at.hour}:${r.at.minute}'), ['21:0']);
    expect(
      today.single.items.map((i) => i.medicine.name),
      unorderedEquals(['Seclo', 'Sergel']),
    );
    expect(state.nextReminder()?.at, today.single.at);
  });

  test('unreviewed drafts cannot be saved', () async {
    final state = demoState();
    await state.auth.verifyCode('+8801712345678', '123456');
    final scan = PrescriptionScan.fromJson(exampleScanJson());
    expect(
      () => state.confirm([
        MedicineDraft.fromScan(scan.medicines[1]),
      ], source: 'scan'),
      throwsStateError,
    );
  });
}
