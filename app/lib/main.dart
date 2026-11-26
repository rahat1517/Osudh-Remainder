import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'data/auth_repository.dart';
import 'data/backend_api.dart';
import 'data/medicine_repository.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig();
  final AppState state;
  if (config.hasSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );
    final client = Supabase.instance.client;
    final auth = SupabaseAuthRepository(client);
    state = AppState(
      auth: auth,
      medicines: SupabaseMedicineRepository(client),
      api: HttpBackendApi(
        config.backendUrl,
        accessToken: () => auth.accessToken,
      ),
    );
  } else {
    state = AppState(
      auth: DemoAuthRepository(),
      medicines: InMemoryMedicineRepository(),
      api: HttpBackendApi(config.backendUrl),
    );
  }
  await state.refresh();
  runApp(OshudhApp(state: state));
}

class OshudhApp extends StatelessWidget {
  const OshudhApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Bangla by default; English will be selectable in settings.
        locale: const Locale('bn'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Consumer<AppState>(
          builder: (context, s, _) =>
              s.signedIn ? const HomeScreen() : const WelcomeScreen(),
        ),
      ),
    );
  }
}
