import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

/// A newer pilot build than the one installed.
class AppUpdate {
  const AppUpdate({required this.build, required this.url, this.notes});

  final int build;
  final String url;
  final String? notes;
}

/// Reads `latest.json` from the public release bucket and picks the APK for this phone.
///
/// Phones only install the build for their processor type (ABI); a universal APK is too large for
/// the free storage plan, so each type has its own file:
///
/// ```json
/// {"build": 42, "notes": "…", "apks": {"arm64-v8a": "https://…", "armeabi-v7a": "https://…"}}
/// ```
class UpdateChecker {
  UpdateChecker({
    required this.manifestUrl,
    required this.installedBuild,
    Future<List<String>> Function()? supportedAbis,
    http.Client? client,
  }) : _abis = supportedAbis ?? _deviceAbis,
       _client = client ?? http.Client();

  final Uri manifestUrl;

  /// Build number of this APK (0 for development builds, which never ask to update).
  final int installedBuild;
  final Future<List<String>> Function() _abis;
  final http.Client _client;

  static Future<List<String>> _deviceAbis() async =>
      (await DeviceInfoPlugin().androidInfo).supportedAbis;

  /// The newer build for this phone, or null when up to date, offline or not applicable.
  Future<AppUpdate?> check() async {
    if (installedBuild <= 0) return null;
    try {
      final r = await _client
          .get(manifestUrl, headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final json = decoded;
      final build = switch (json['build']) {
        final num n => n.toInt(),
        _ => 0,
      };
      if (build <= installedBuild) return null;
      final apks = switch (json['apks']) {
        final Map<String, dynamic> m => m,
        _ => const <String, dynamic>{},
      };
      // Most preferred ABI first, as Android lists them
      for (final abi in await _abis()) {
        if (apks[abi] case final String url) {
          return AppUpdate(
            build: build,
            url: url,
            notes: json['notes'] as String?,
          );
        }
      }
      return null;
    } on Object {
      // An update check must never get in the way: bad JSON, offline, no device info...
      return null;
    }
  }
}
