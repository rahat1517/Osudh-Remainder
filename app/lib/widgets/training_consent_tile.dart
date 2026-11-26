import 'package:material_ui/material_ui.dart';

import '../data/training_consent.dart';
import '../l10n/generated/app_localizations.dart';

class TrainingConsentTile extends StatefulWidget {
  const TrainingConsentTile({super.key, required this.repository});

  final TrainingConsentRepository repository;

  @override
  State<TrainingConsentTile> createState() => _TrainingConsentTileState();
}

class _TrainingConsentTileState extends State<TrainingConsentTile> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    widget.repository.isGranted().then((g) {
      if (mounted) setState(() => _granted = g);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final granted = _granted;
    if (granted == null) return const SizedBox.shrink();
    return SwitchListTile(
      key: const Key('trainingConsent'),
      secondary: const Icon(Icons.volunteer_activism_outlined),
      title: Text(l.trainingConsentTitle),
      subtitle: Text(l.trainingConsentBody),
      isThreeLine: true,
      value: granted,
      onChanged: (v) async {
        setState(() => _granted = v);
        await widget.repository.set(v);
      },
    );
  }
}
