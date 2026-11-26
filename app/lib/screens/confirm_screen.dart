import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/medicine_draft.dart';
import '../data/models.dart';
import '../l10n/codes.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/medicine_editor.dart';

String problemLabel(AppLocalizations l, DraftProblem p) => switch (p) {
  DraftProblem.nameRequired => l.problemNameRequired,
  DraftProblem.doseInvalid => l.problemDoseInvalid,
  DraftProblem.durationRequired => l.problemDurationRequired,
  DraftProblem.needsReview => l.problemNeedsReview,
};

/// Review screen. Nothing is scheduled until the user taps Confirm, and Confirm is only enabled
/// when every medicine is complete and every uncertain field has been reviewed.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({
    super.key,
    required this.drafts,
    required this.source,
    this.imageQuality,
    this.warnings = const [],
  });

  ConfirmScreen.fromScan(PrescriptionScan scan, {super.key})
    : drafts = [for (final m in scan.medicines) MedicineDraft.fromScan(m)],
      source = 'scan',
      imageQuality = scan.imageQuality,
      warnings = scan.warnings;

  ConfirmScreen.manual({super.key})
    : drafts = [MedicineDraft.manual()],
      source = 'manual',
      imageQuality = null,
      warnings = const [];

  final List<MedicineDraft> drafts;
  final String source;
  final String? imageQuality;
  final List<Notice> warnings;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final List<MedicineDraft> _drafts = [...widget.drafts];
  bool _saving = false;

  List<DraftProblem> get _problems =>
      {for (final d in _drafts) ...d.problems}.toList();

  Future<void> _confirm() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await context.read<AppState>().confirm(
        _drafts,
        source: widget.source,
        imageQuality: widget.imageQuality,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(l.saved)));
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final api = context.read<AppState>().api;
    final problems = _problems;
    final ready = _drafts.isNotEmpty && problems.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l.confirmTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.confirmHelp),
          for (final w in widget.warnings)
            if (localizeNotice(l, w) case final text?)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(text),
                ),
              ),
          for (final (i, draft) in _drafts.indexed)
            MedicineEditor(
              key: ObjectKey(draft),
              draft: draft,
              api: api,
              onChanged: () => setState(() {}),
              onRemove: _drafts.length > 1
                  ? () => setState(() => _drafts.removeAt(i))
                  : null,
            ),
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => _drafts.add(MedicineDraft.manual())),
            icon: const Icon(Icons.add),
            label: Text(l.addAnother),
          ),
          const SizedBox(height: 96),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in problems)
                Text(
                  problemLabel(l, p),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('confirm'),
                onPressed: ready && !_saving ? _confirm : null,
                child: Text(l.confirmButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
