import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import 'ramadan_screen.dart';
import 'report_screen.dart';

const privacyPolicyUrl =
    'https://github.com/rahat1517/Osudh-Remainder/blob/main/docs/legal/privacy-policy.md';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _delete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteAccount),
        content: Text(l.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('confirmDelete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deleteAccountButton),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await state.deleteAccount();
      navigator.popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.privacyPolicy),
            subtitle: Text('${l.privacySummary}\n$privacyPolicyUrl'),
            isThreeLine: true,
          ),
          ListTile(
            leading: const Icon(Icons.insights),
            title: Text(l.reportTitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReportScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.nightlight_round),
            title: Text(l.ramadanTitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RamadanScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l.signOut),
            onTap: () async {
              await state.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
          ListTile(
            key: const Key('deleteAccount'),
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l.deleteAccount,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _delete(context),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.disclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
