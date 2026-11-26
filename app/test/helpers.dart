import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/data/assistant.dart';
import 'package:oshudh_reminder/data/auth_repository.dart';
import 'package:oshudh_reminder/data/backend_api.dart';
import 'package:oshudh_reminder/data/medicine_repository.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/main.dart';
import 'package:oshudh_reminder/state/app_state.dart';

/// The backend's real response, kept current by backend/tests/test_api_contract.py.
Map<String, dynamic> exampleScanJson() => jsonDecode(
  File('../spec/api/examples/prescription_result.json').readAsStringSync(),
) as Map<String, dynamic>;

class FakeBackendApi implements BackendApi {
  FakeBackendApi({this.scan, this.error, this.drugs = const []});

  PrescriptionScan? scan;
  ApiException? error;
  List<Drug> drugs;
  int extractCalls = 0;

  @override
  Future<PrescriptionScan> extractPrescription(
    Uint8List image, {
    String filename = 'rx.jpg',
  }) async {
    extractCalls++;
    if (error != null) throw error!;
    return scan ?? PrescriptionScan.fromJson(exampleScanJson());
  }

  /// Replies returned by the assistant, in order.
  final List<AssistantReply> assistantReplies = [];
  final List<Map<String, dynamic>> assistantContexts = [];

  @override
  Future<AssistantReply> askAssistant(
    List<ChatTurn> history,
    Map<String, dynamic> context,
  ) async {
    assistantContexts.add(context);
    if (error != null) throw error!;
    return assistantReplies.removeAt(0);
  }

  final List<Map<String, dynamic>> trainingLabels = [];

  @override
  Future<void> submitTrainingExample(
    Uint8List image,
    Map<String, dynamic> label,
  ) async => trainingLabels.add(label);

  @override
  Future<List<Drug>> searchDrugs(String query, {int limit = 8}) async => drugs
      .where((d) => d.brand.toLowerCase().startsWith(query.toLowerCase()))
      .toList();
}

/// 2026-11-26 10:00 in Dhaka.
DateTime fixedNow() => DateTime.utc(2026, 11, 26, 4);

AppState demoState({FakeBackendApi? api, InMemoryMedicineRepository? repo}) =>
    AppState(
      auth: DemoAuthRepository(),
      medicines: repo ?? InMemoryMedicineRepository(now: fixedNow),
      api: api ?? FakeBackendApi(),
      clock: fixedNow,
    );

Future<void> pumpApp(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(OshudhApp(state: state));
  await tester.pumpAndSettle();
}
