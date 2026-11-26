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
  Future<PrescriptionScan> extractPrescription(
    Uint8List image, {
    String filename = 'rx.jpg',
  });

  Future<List<Drug>> searchDrugs(String query, {int limit = 8});

  Future<AssistantReply> askAssistant(
    List<ChatTurn> history,
    Map<String, dynamic> context,
  );
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
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/prescriptions/extract'),
          )
          ..headers.addAll(_headers)
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
