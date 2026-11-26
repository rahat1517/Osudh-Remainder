import 'package:material_ui/material_ui.dart';

/// অ্যাপের থিম।
///
/// বয়স্ক ব্যবহারকারীদের কথা মাথায় রেখে: বড় লেখা, বড় বাটন, স্পষ্ট রং।
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'HindSiliguri';

  /// প্রধান রং: শান্ত সবুজ (স্বাস্থ্য ও ভরসার অনুভূতি)।
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
      // সাধারণের চেয়ে একটু বড় লেখা, যাতে বয়স্করা সহজে পড়তে পারেন।
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
