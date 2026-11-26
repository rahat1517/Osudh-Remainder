import 'package:material_ui/material_ui.dart';

import 'l10n/generated/app_localizations.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const OshudhApp());
}

class OshudhApp extends StatelessWidget {
  const OshudhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // বাংলা default। পরে সেটিংস থেকে ইংরেজি বেছে নেওয়া যাবে।
      locale: const Locale('bn'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: const WelcomeScreen(),
    );
  }
}
