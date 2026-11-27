import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../updates/update_checker.dart';

/// "A new version is available": opens the APK download; Android then asks to install it
/// (apps installed outside the Play Store cannot update silently).
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      key: const Key('updateBanner'),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.updateTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.updateBody),
            if (update.notes case final notes? when notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  notes,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('updateButton'),
              onPressed: () => launchUrl(
                Uri.parse(update.url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.download),
              label: Text(l.updateButton),
            ),
          ],
        ),
      ),
    );
  }
}
