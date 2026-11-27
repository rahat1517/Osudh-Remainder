import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/medicine_draft.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/insights/prices.dart';
import 'package:oshudh_reminder/schedule/schedule_models.dart';
import 'package:oshudh_reminder/screens/medicines_screen.dart';
import 'package:oshudh_reminder/state/app_state.dart';

import 'helpers.dart';

const seclo = Drug(
  id: 9,
  brand: 'Seclo',
  strength: '20 mg',
  generic: 'Omeprazole',
  form: 'Capsule',
  unitPriceBdt: 6,
);
const losectil = Drug(
  id: 11,
  brand: 'Losectil',
  strength: '20 mg',
  generic: 'Omeprazole',
  form: 'Capsule',
  unitPriceBdt: 5,
);

DrugAlternatives secloAlternatives({bool verified = false}) => DrugAlternatives(
  drug: seclo,
  alternatives: [(drug: losectil, savingPercent: 16)],
  pricesVerified: verified,
);

Future<(AppState, FakeBackendApi)> stateWithSeclo({
  int? durationDays,
  Map<int, DrugAlternatives>? alternatives,
}) async {
  final api = FakeBackendApi(
    alternatives: alternatives ?? {seclo.id: secloAlternatives()},
  );
  final state = AppState(
    auth: DemoAuthRepository(),
    medicines: InMemoryMedicineRepository(now: fixedNow),
    api: api,
    clock: fixedNow,
  );
  await state.auth.verifyCode('+8801712345678', '123456');
  final d = MedicineDraft.manual()
    ..name.edit('Seclo')
    ..dose.edit('1+0+1');
  if (durationDays == null) {
    d.continueIndefinitely = true;
  } else {
    d.durationDays.edit(durationDays);
  }
  d.drugId = seclo.id;
  await state.confirm([d], source: 'manual');
  return (state, api);
}

Future<void> openMedicines(WidgetTester tester, AppState state) async {
  await pumpApp(tester, state);
  Navigator.of(tester.element(find.byType(Scaffold).first))
      .push(MaterialPageRoute<void>(builder: (_) => const MedicinesScreen()));
  await tester.pumpAndSettle();
}

void main() {
  group('saving', () {
    test('a month of a twice-daily capsule', () {
      expect(
        saving(current: seclo, cheaper: losectil, piecesPerDay: 2, days: 30),
        60,
      );
    });

    test('no saving for liquids, missing prices or "as needed"', () {
      const syrup = Drug(
        id: 1,
        brand: 'A',
        strength: '120 mg/5 ml',
        generic: 'Paracetamol',
        form: 'Suspension',
        unitPriceBdt: 35,
      );
      const cheapSyrup = Drug(
        id: 2,
        brand: 'B',
        strength: '120 mg/5 ml',
        generic: 'Paracetamol',
        form: 'Suspension',
        unitPriceBdt: 30,
      );
      expect(
        saving(current: syrup, cheaper: cheapSyrup, piecesPerDay: 3, days: 30),
        isNull,
      );
      const noPrice = Drug(
        id: 3,
        brand: 'C',
        strength: '20 mg',
        generic: 'Omeprazole',
        form: 'Capsule',
      );
      expect(
        saving(current: noPrice, cheaper: losectil, piecesPerDay: 2, days: 30),
        isNull,
      );
      expect(
        saving(current: seclo, cheaper: losectil, piecesPerDay: 0, days: 30),
        isNull,
      );
    });

    test('no daily saving for a priced pack (bottle, tube)', () {
      const napaSyrup = Drug(
        id: 4,
        brand: 'Napa',
        strength: '120 mg/5 ml',
        generic: 'Paracetamol',
        form: 'Tablet', // even when the form looks like a piece
        unitPriceBdt: 35,
        pack: '60 ml bottle',
      );
      const other = Drug(
        id: 5,
        brand: 'B',
        strength: '120 mg/5 ml',
        generic: 'Paracetamol',
        form: 'Tablet',
        unitPriceBdt: 30,
        pack: '60 ml bottle',
      );
      expect(
        saving(current: napaSyrup, cheaper: other, piecesPerDay: 3, days: 30),
        isNull,
      );
    });

    test('formatTaka drops needless decimals', () {
      expect(formatTaka(6), '6');
      expect(formatTaka(1.2), '1.20');
      expect(formatTaka(0.6), '0.60');
    });

    test('pieces per day follows the dose pattern', () async {
      final (state, _) = await stateWithSeclo();
      expect(piecesPerDay(state.active.single, const ScheduleSettings()), 2);
    });
  });

  testWidgets('shows the approximate price and cheaper brands', (tester) async {
    final (state, api) = await stateWithSeclo();
    await openMedicines(tester, state);
    expect(find.text('প্রতিটি আনুমানিক ৬ টাকা'), findsOneWidget);
    await tester.tap(find.byKey(Key('cheaper-${state.active.single.id}')));
    await tester.pumpAndSettle();
    expect(find.text('একই ওষুধ, কম দামে'), findsOneWidget);
    expect(find.text('Losectil 20 mg'), findsOneWidget);
    // 1 taka less, twice a day, for a month
    expect(find.textContaining('মাসে প্রায় ৬০ টাকা কম'), findsOneWidget);
    expect(find.textContaining('ডাক্তার বা ফার্মাসিস্টকে'), findsOneWidget);
    expect(find.textContaining('আনুমানিক; দোকানে'), findsOneWidget);
    // Nothing changed: the medicine is still Seclo
    expect(state.active.single.name, 'Seclo');
    expect(api.alternativesCalls, 1);
  });

  testWidgets('a short course shows the saving for the course', (tester) async {
    final (state, _) = await stateWithSeclo(durationDays: 7);
    await openMedicines(tester, state);
    await tester.tap(find.byKey(Key('cheaper-${state.active.single.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('এই কোর্সে প্রায় ১৪ টাকা কম'), findsOneWidget);
  });

  testWidgets('a pack price names the pack', (tester) async {
    const syrup = Drug(
      id: 9,
      brand: 'Seclo',
      strength: '20 mg',
      generic: 'Omeprazole',
      form: 'Oral Suspension',
      unitPriceBdt: 35,
      pack: '60 ml bottle',
    );
    final (state, _) = await stateWithSeclo(
      alternatives: {
        seclo.id: const DrugAlternatives(
          drug: syrup,
          alternatives: [],
          pricesVerified: false,
        ),
      },
    );
    await openMedicines(tester, state);
    expect(find.text('60 ml bottle: আনুমানিক ৩৫ টাকা'), findsOneWidget);
  });

  testWidgets('verified prices are not called approximate', (tester) async {
    final (state, _) = await stateWithSeclo(
      alternatives: {seclo.id: secloAlternatives(verified: true)},
    );
    await openMedicines(tester, state);
    expect(find.text('প্রতিটি ৬ টাকা'), findsOneWidget);
  });

  testWidgets('without the server the list still works, with no price', (
    tester,
  ) async {
    final (state, api) = await stateWithSeclo(alternatives: {});
    await openMedicines(tester, state);
    expect(find.text('Seclo'), findsOneWidget);
    expect(find.textContaining('টাকা'), findsNothing);
    expect(api.alternativesCalls, greaterThan(0));
  });
}
