import 'package:material_ui/material_ui.dart';

/// App theme.
///
/// Designed for older users: larger text, large touch targets, clear colours.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'HindSiliguri';

  /// Primary colour: a calm green, associated with health and trust.
  static const Color seed = Color(0xFF0F7B5F);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      useMaterial3: true,
    );
    return base.copyWith(
      // Slightly larger than Material defaults for readability.
      textTheme: base.textTheme.merge(
        const TextTheme(
          headlineMedium: TextStyle(fontSize: 30),
          titleLarge: TextStyle(fontSize: 24),
          titleMedium: TextStyle(fontSize: 19),
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
          bodySmall: TextStyle(fontSize: 14),
          labelLarge: TextStyle(fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
