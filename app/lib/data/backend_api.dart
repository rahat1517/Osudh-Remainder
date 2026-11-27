import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'assistant.dart';
import 'models.dart';

/// An error from the backend with a stable [code] (spec/api/codes.json), or `network_error`.
class ApiException implements Exception {
  const ApiException(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => 'ApiException($code): $message';
}

abstract interface class BackendApi {
  /// [cloudOk]: the user agreed that a photo the server's own reader is unsure of may be read by
  /// Google's AI (with personal lines blacked out first).
  Future<PrescriptionScan> extractPrescription(
    Uint8List image, {
    String filename = 'rx.jpg',
    bool cloudOk = false,
  });

  Future<List<Drug>> searchDrugs(String query, {int limit = 8});

  /// Cheaper brands of the same medicine as catalogue drug [drugId].
  Future<DrugAlternatives> drugAlternatives(int drugId);

  Future<AssistantReply> askAssistant(
    List<ChatTurn> history,
    Map<String, dynamic> context,
  );

  /// Shares a confirmed scan for improving the reader (only when the user has opted in).
  Future<void> submitTrainingExample(
    Uint8List image,
    Map<String, dynamic> label,
  );

  /// Starts waking the server, without waiting for it. On the free plan it sleeps when idle and
  /// takes a minute or more to start; called when the scan screen opens, it is awake by the time
  /// the photo is taken. Never throws.
  Future<void> wakeUp();
}

class HttpBackendApi implements BackendApi {
  HttpBackendApi(this.baseUrl, {http.Client? client, this.accessToken})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Returns the current user's access token, sent as a bearer token.
  final String? Function()? accessToken;

  Map<String, String> get _headers {
    final token = accessToken?.call();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  @override
  Future<PrescriptionScan> extractPrescription(
    Uint8List image, {
    String filename = 'rx.jpg',
    bool cloudOk = false,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/prescriptions/extract'),
          )
          ..headers.addAll(_headers)
          ..fields['cloud_ok'] = cloudOk ? 'true' : 'false'
          ..files.add(
            http.MultipartFile.fromBytes('image', image, filename: filename),
          );
    final response = await _send(
      () async => http.Response.fromStream(await _client.send(request)),
    );
    return PrescriptionScan.fromJson(_decode(response) as Map<String, dynamic>);
  }

  @override
  Future<List<Drug>> searchDrugs(String query, {int limit = 8}) async {
    final uri = Uri.parse('$baseUrl/drugs/search')
        .replace(queryParameters: {'q': query, 'limit': '$limit'});
    final response = await _send(() => _client.get(uri, headers: _headers));
    return [
      for (final c in _decode(response) as List)
        Drug.fromJson((c as Map)['drug'] as Map<String, dynamic>),
    ];
  }

  @override
  Future<DrugAlternatives> drugAlternatives(int drugId) async {
    final uri = Uri.parse('$baseUrl/drugs/$drugId/alternatives');
    final response = await _send(() => _client.get(uri, headers: _headers));
    return DrugAlternatives.fromJson(_decode(response) as Map<String, dynamic>);
  }

  @override
  Future<AssistantReply> askAssistant(
    List<ChatTurn> history,
    Map<String, dynamic> context,
  ) async {
    final body = jsonEncode({
      // The backend accepts at most 20 messages; older turns add little
      'messages': [
        for (final t
            in history.length > 20
                ? history.sublist(history.length - 20)
                : history)
          t.toJson(),
      ],
      'context': context,
    });
    final response = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/assistant/chat'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: body,
      ),
    );
    return AssistantReply.fromJson(_decode(response) as Map<String, dynamic>);
  }

  @override
  Future<void> submitTrainingExample(
    Uint8List image,
    Map<String, dynamic> label,
  ) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/training/examples'))
          ..headers.addAll(_headers)
          ..fields['label'] = jsonEncode(label)
          ..files.add(
            http.MultipartFile.fromBytes('image', image, filename: 'rx.jpg'),
          );
    final response = await _send(
      () async => http.Response.fromStream(await _client.send(request)),
    );
    _decode(response);
  }

  @override
  Future<void> wakeUp() async {
    try {
      await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(minutes: 3));
    } on Object {
      // Only a head start: the scan itself reports any real problem
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 90));
    } on Exception catch (e) {
      throw ApiException('network_error', '$e');
    }
  }

  Object? _decode(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final detail = body is Map ? body['detail'] : null;
    if (detail is Map && detail['code'] is String) {
      throw ApiException(
        detail['code'] as String,
        detail['message'] as String? ?? '',
      );
    }
    throw ApiException('server_error', 'HTTP ${r.statusCode}');
  }
}
