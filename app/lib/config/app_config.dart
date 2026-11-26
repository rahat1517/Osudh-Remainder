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
  });

  final String backendUrl;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
