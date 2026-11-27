import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oshudh_reminder/data/backend_api.dart';

void main() {
  test('wakeUp asks the server for its health, without sign-in', () async {
    final seen = <http.Request>[];
    final api = HttpBackendApi(
      'https://api.example.org',
      client: MockClient((request) async {
        seen.add(request);
        return http.Response('{"status":"ok"}', 200);
      }),
    );
    await api.wakeUp();
    expect(seen.single.method, 'GET');
    expect(seen.single.url.toString(), 'https://api.example.org/health');
  });

  test('wakeUp never throws: the scan reports real problems', () async {
    final api = HttpBackendApi(
      'https://api.example.org',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await api.wakeUp(); // completes normally
  });
}
