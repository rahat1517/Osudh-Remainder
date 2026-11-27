import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alarms/alarm_payload.dart';
import 'alarms/alarm_runtime.dart';
import 'alarms/alarm_service.dart';
import 'alarms/dose_log_sync.dart';
import 'alarms/local_store.dart';
import 'alarms/speaker.dart';
import 'caregivers/caregiver_repository.dart';
import 'caregivers/push_registration.dart';
import 'config/app_config.dart';
import 'data/auth_repository.dart';
import 'data/backend_api.dart';
import 'data/medicine_repository.dart';
import 'data/reminder_channels.dart';
import 'data/training_consent.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/alarm_screen.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'updates/update_checker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig();
  final store = await LocalStore.open();
  final alarms = await createAlarmService(store);
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
      store: store,
      alarms: alarms,
      logSync: SupabaseDoseLogSync(client),
      caregivers: SupabaseCaregiverRepository(client),
      channels: SupabaseReminderChannelsRepository(client),
      trainingConsent: SupabaseTrainingConsentRepository(client),
      updates: config.updateManifestUrl == null
          ? null
          : UpdateChecker(
              manifestUrl: config.updateManifestUrl!,
              installedBuild: config.buildNumber,
            ),
    );
    final push = config.hasFirebase
        ? FirebasePushRegistration(
            client,
            FirebaseOptions(
              apiKey: config.firebaseApiKey,
              appId: config.firebaseAppId,
              messagingSenderId: config.firebaseSenderId,
              projectId: config.firebaseProjectId,
            ),
          )
        : NoPushRegistration();
    if (state.signedIn) await push.register().catchError((Object _) {});
  } else {
    final auth = DemoAuthRepository();
    state = AppState(
      auth: auth,
      medicines: InMemoryMedicineRepository(),
      api: HttpBackendApi(config.backendUrl),
      store: store,
      alarms: alarms,
      caregivers: InMemoryCaregiverRepository(
        currentUser: () => auth.currentUserId ?? '',
      ),
    );
  }

  final navigatorKey = GlobalKey<NavigatorState>();
  // When the session changes outside the sign-in screens (restored at startup, or expired), go
  // back to the first screen, which shows home or sign-in; screens opened on top would otherwise
  // stay, signed out, or leave the sign-in screens over a restored session.
  var wasSignedIn = state.signedIn;
  state.addListener(() {
    if (state.signedIn == wasSignedIn) return;
    wasSignedIn = state.signedIn;
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  });
  final speaker = TtsSpeaker();
  void openAlarm(String payload) => navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => AlarmScreen(
        payload: AlarmPayload.decode(payload),
        service: alarms,
        speaker: speaker,
      ),
    ),
  );

  final launchPayload = await initNotifications(
    onResponse: (response) async {
      if (response.actionId == null) {
        if (response.payload != null) openAlarm(response.payload!);
      } else {
        await alarms.handleAction(response.actionId, response.payload);
        await state.refresh();
      }
    },
  );
  await state.refresh();
  unawaited(state.checkForUpdate());
  runApp(
    OshudhApp(state: state, navigatorKey: navigatorKey, alarmService: alarms),
  );
  if (launchPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => openAlarm(launchPayload),
    );
  }
}

class OshudhApp extends StatelessWidget {
  const OshudhApp({
    super.key,
    required this.state,
    this.navigatorKey,
    this.alarmService,
  });

  final AppState state;
  final GlobalKey<NavigatorState>? navigatorKey;
  final AlarmService? alarmService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
