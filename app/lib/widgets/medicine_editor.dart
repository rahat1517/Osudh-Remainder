import 'package:material_ui/material_ui.dart';

import '../data/backend_api.dart';
import '../data/medicine_draft.dart';
import '../data/models.dart';
import '../l10n/codes.dart';
import '../l10n/generated/app_localizations.dart';
import '../schedule/schedule_models.dart';
import 'confidence_style.dart';

String timingLabel(AppLocalizations l, Timing t) => switch (t) {
  Timing.beforeMeal => l.timingBeforeMeal,
  Timing.afterMeal => l.timingAfterMeal,
  Timing.withMeal => l.timingWithMeal,
  Timing.emptyStomach => l.timingEmptyStomach,
  Timing.bedtime => l.timingBedtime,
  Timing.notSpecified => l.timingNotSpecified,
};

/// Editor for one medicine on the confirm screen.
class MedicineEditor extends StatefulWidget {
  const MedicineEditor({
    super.key,
    required this.draft,
    required this.api,
    required this.onChanged,
    this.onRemove,
  });

  final MedicineDraft draft;
  final BackendApi api;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<MedicineEditor> createState() => _MedicineEditorState();
}

class _MedicineEditorState extends State<MedicineEditor> {
  late final _strength = TextEditingController(
    text: widget.draft.strength.value ?? '',
  );
  late final _dose = TextEditingController(text: widget.draft.dose.value ?? '');
  late final _days = TextEditingController(
    text: widget.draft.durationDays.value?.toString() ?? '',
  );

  MedicineDraft get d => widget.draft;

  void _changed(VoidCallback update) {
    setState(update);
    widget.onChanged();
  }

  @override
  void dispose() {
    _strength.dispose();
    _dose.dispose();
    _days.dispose();
    super.dispose();
  }

  Widget _frame<T>(
    DraftField<T> field, {
    required String label,
    required Widget child,
  }) {
    final l = AppLocalizations.of(context);
    final style = confidenceStyle(context, field.confidence, field.reviewed);
    final note = field.note == null ? null : localizeNotice(l, field.note!);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: style.fill,
        border: Border.all(color: style.border, width: field.reviewed ? 1 : 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (style.icon != null)
                Icon(style.icon, size: 20, color: style.border),
              if (style.icon != null) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (field.needsReview)
                TextButton.icon(
                  onPressed: () => _changed(field.markReviewed),
                  icon: const Icon(Icons.check),
                  label: Text(l.looksRight),
                ),
            ],
          ),
          child,
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(note, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d.rawText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.writtenAs(d.rawText!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            _frame(d.name, label: l.fieldName, child: _nameField()),
            _frame(
              d.strength,
              label: l.fieldStrength,
              child: TextField(
                key: const Key('strength'),
                controller: _strength,
                onChanged: (v) => _changed(() => d.strength.edit(v)),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.asNeeded),
              value: d.asNeeded,
              onChanged: (v) => _changed(() => d.asNeeded = v),
            ),
            if (!d.asNeeded) ...[
              _frame(
                d.dose,
                label: l.fieldDose,
                child: TextField(
                  key: const Key('dose'),
                  controller: _dose,
                  decoration: InputDecoration(hintText: l.fieldDoseHint),
                  onChanged: (v) => _changed(() => d.dose.edit(v)),
                ),
              ),
              _frame(
                d.timing,
                label: l.fieldTiming,
                child: DropdownButton<Timing>(
                  key: const Key('timing'),
                  isExpanded: true,
                  value: d.timing.value,
                  items: [
                    for (final t in Timing.values)
                      DropdownMenuItem(
                        value: t,
                        child: Text(timingLabel(l, t)),
                      ),
                  ],
                  onChanged: (t) => _changed(() => d.timing.edit(t)),
                ),
              ),
              _frame(
                d.durationDays,
                label: l.fieldDuration,
                child: Column(
                  children: [
                    if (!d.continueIndefinitely)
                      TextField(
                        key: const Key('days'),
                        controller: _days,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _changed(
                          () => d.durationDays.edit(int.tryParse(v.trim())),
                        ),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.continueIndefinitely),
                      value: d.continueIndefinitely,
                      onChanged: (v) => _changed(() {
                        d.continueIndefinitely = v ?? false;
                        d.durationDays.markReviewed();
                      }),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.onRemove != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l.removeMedicine),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nameField() => Autocomplete<Drug>(
    initialValue: TextEditingValue(text: d.name.value ?? ''),
    displayStringForOption: (drug) => drug.brand,
    optionsBuilder: (value) async {
      final q = value.text.trim();
      if (q.length < 2) return const <Drug>[];
      try {
        return await widget.api.searchDrugs(q);
      } on ApiException {
        return d.alternatives;
      }
    },
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final drug in options)
                ListTile(
                  title: Text(drug.label),
                  subtitle: Text('${drug.generic} · ${drug.form}'),
                  onTap: () => onSelected(drug),
                ),
            ],
          ),
        ),
      ),
    ),
    onSelected: (drug) => _changed(() {
      d.selectDrug(drug);
      _strength.text = d.strength.value ?? '';
    }),
    fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
      key: const Key('name'),
      controller: controller,
      focusNode: focus,
      onChanged: (v) => _changed(() {
        d.name.edit(v);
        // Typed by hand: no longer linked to a catalogue entry
        d.drugId = null;
        d.generic = null;
      }),
    ),
  );
}
