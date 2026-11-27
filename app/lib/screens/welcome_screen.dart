import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import 'auth_screens.dart';

/// First screen for signed-out users. "শুরু করুন" starts at once, without a phone number or SMS
/// code (free for everyone); signing in with a number is the second option.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _starting = false;

  Future<void> _start() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    try {
      await context.read<AppState>().startWithoutSignIn();
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l.startFailed)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.medication_rounded,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.appTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.welcomeSubtitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                key: const Key('start'),
                onPressed: _starting ? null : _start,
                child: Text(l10n.getStarted),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('phoneSignIn'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
                ),
                child: Text(l10n.signInWithPhone),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.disclaimer,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
