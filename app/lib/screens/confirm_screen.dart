import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/medicine_draft.dart';
import '../data/models.dart';
import '../insights/insights.dart';
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
    this.forUserId,
    this.image,
  });

  ConfirmScreen.fromScan(
    PrescriptionScan scan, {
    super.key,
    this.forUserId,
    this.image,
  }) : drafts = [for (final m in scan.medicines) MedicineDraft.fromScan(m)],
       source = 'scan',
       imageQuality = scan.imageQuality,
       warnings = scan.warnings;

  ConfirmScreen.manual({super.key, this.forUserId})
    : drafts = [MedicineDraft.manual()],
      source = 'manual',
      imageQuality = null,
      warnings = const [],
      image = null;

  final List<MedicineDraft> drafts;
  final String source;
  final String? imageQuality;
  final List<Notice> warnings;

  /// Saves for a patient the user looks after (edit permission) instead of for the user.
  final String? forUserId;

  /// The scanned photo, shared for training only if the user opted in.
  final Uint8List? image;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final List<MedicineDraft> _drafts = [...widget.drafts];
  bool _saving = false;
  bool _edited = false;

  List<DraftProblem> get _problems =>
      {for (final d in _drafts) ...d.problems}.toList();

  /// After the first scan the user confirms: may confirmed scans help improve the reader?
  /// Asked once, with no answer chosen in advance; changeable in Settings.
  Future<void> _askAboutTrainingOnce() async {
    final state = context.read<AppState>();
    if (widget.image == null || widget.forUserId != null) return;
    if (!await state.shouldAskTrainingConsent() || !mounted) return;
    final l = AppLocalizations.of(context);
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l.trainingAskTitle),
        content: SingleChildScrollView(child: Text(l.trainingAskBody)),
        actions: [
          TextButton(
            key: const Key('trainingAskNo'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.trainingAskNo),
          ),
          FilledButton(
            key: const Key('trainingAskYes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.trainingAskYes),
          ),
        ],
      ),
    );
    await state.answerTrainingConsent(granted ?? false);
  }

  Future<void> _confirm() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await _askAboutTrainingOnce();
      if (!mounted) return;
      await context.read<AppState>().confirm(
        _drafts,
        source: widget.source,
        imageQuality: widget.imageQuality,
        forUserId: widget.forUserId,
        scanImage: widget.image,
      );
      if (!mounted) return;
      if (widget.forUserId == null) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        Navigator.of(context).pop(); // back to the patient's dashboard
      }
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
            // The help line above already says this; a second card only repeats it
            if (w.code != 'review_highlighted_fields')
              if (localizeNotice(l, w) case final text?)
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(text),
                  ),
                ),
          for (final g in duplicateTherapies([
            ...context.read<AppState>().active,
            for (final (i, d) in _drafts.indexed)
              if (d.generic != null)
                Medicine(
                  id: 'draft-$i',
                  name: d.name.value ?? '',
                  generic: d.generic,
                  startAt: DateTime.now(),
                ),
          ]))
            // Only duplicates this prescription adds; existing ones are shown on the home screen
            if (g.medicines.any((m) => m.id.startsWith('draft-')))
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text(l.duplicateTitle),
                  subtitle: Text(
                    l.duplicateBody(
                      g.medicines.map((m) => m.label).join(', '),
                      g.ingredient,
                    ),
                  ),
                ),
              ),
          for (final (i, draft) in _drafts.indexed)
            MedicineEditor(
              key: ObjectKey(draft),
              draft: draft,
              api: api,
              onChanged: () => setState(() => _edited = true),
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
              // A new, empty form should not open with a list of errors: show them once the user
              // has started (a scan is different: the highlighted fields need attention at once)
              if (_edited || widget.source == 'scan')
                for (final p in problems)
                  Text(
                    problemLabel(l, p),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
