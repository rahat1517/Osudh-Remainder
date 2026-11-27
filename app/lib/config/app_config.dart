/// Build-time configuration, passed with `--dart-define`:
///
/// ```bash
/// flutter run --dart-define=BACKEND_URL=https://api.example.com \
///             --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///             --dart-define=SUPABASE_PUBLISHABLE_KEY=...
/// ```
///
/// Without Supabase settings the app runs in demo mode: data is kept in memory and the
/// one-time code is always 123456. Demo mode is for development only.
class AppConfig {
  const AppConfig({
    this.backendUrl = const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'http://10.0.2.2:8000', // Android emulator → host machine
    ),
    this.supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
    this.supabasePublishableKey = const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    this.firebaseApiKey = const String.fromEnvironment('FIREBASE_API_KEY'),
    this.firebaseAppId = const String.fromEnvironment('FIREBASE_APP_ID'),
    this.firebaseSenderId = const String.fromEnvironment('FIREBASE_SENDER_ID'),
    this.buildNumber = const int.fromEnvironment('BUILD_NUMBER'),
    this.firebaseProjectId = const String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
    ),
  });

  /// Pilot build number (set by the Pilot APK workflow); 0 in development builds.
  final int buildNumber;

  /// Where pilot builds announce the newest version (public storage bucket).
  Uri? get updateManifestUrl => supabaseUrl.isEmpty
      ? null
      : Uri.parse(
          '$supabaseUrl/storage/v1/object/public/app-releases/latest.json',
        );

  /// Firebase Cloud Messaging for caregiver alerts (optional).
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseSenderId;
  final String firebaseProjectId;

  bool get hasFirebase => [
    firebaseApiKey,
    firebaseAppId,
    firebaseSenderId,
    firebaseProjectId,
  ].every((v) => v.isNotEmpty);

  final String backendUrl;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
