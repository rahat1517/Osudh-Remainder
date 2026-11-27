import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../insights/insights.dart';
import '../insights/prices.dart';
import '../l10n/format.dart';
import '../l10n/generated/app_localizations.dart';
import '../schedule/schedule_models.dart';
import '../state/app_state.dart';
import '../widgets/medicine_editor.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  Future<void> _stop(BuildContext context, String id, String name) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.stopConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.stopMedicine),
          ),
        ],
      ),
    );
    if (ok ?? false) await state.stop(id);
  }

  /// Tapping a medicine: change when it is taken, or how many tablets are on hand.
  Future<void> _actions(BuildContext context, Medicine m) async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(m.label, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              key: const Key('editTiming'),
              leading: const Icon(Icons.restaurant),
              title: Text(l.timingEditTitle),
              subtitle: Text(timingLabel(l, m.timing)),
              onTap: () => Navigator.pop(ctx, 'timing'),
            ),
            ListTile(
              key: const Key('editStock'),
              leading: const Icon(Icons.medication),
              title: Text(l.stockTitle),
              onTap: () => Navigator.pop(ctx, 'stock'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'timing':
        await _timing(context, m);
      case 'stock':
        await _stock(context, m.id, m.pillsOnHand);
    }
  }

  Future<void> _timing(BuildContext context, Medicine m) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final picked = await showModalBottomSheet<Timing>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  l.timingEditTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final t in Timing.values)
                ListTile(
                  key: Key('timing-${t.name}'),
                  title: Text(timingLabel(l, t)),
                  trailing: t == m.timing
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, t),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == m.timing || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await state.setTiming(m.id, picked);
    messenger.showSnackBar(SnackBar(content: Text(l.timingChanged(m.label))));
  }

  Future<void> _stock(BuildContext context, String id, double? current) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final controller = TextEditingController(
      text: current == null ? '' : current.toStringAsFixed(0),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.stockTitle),
        content: TextField(
          key: const Key('stockInput'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            helperText: l.stockHelp,
            helperMaxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('saveStock'),
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (value != null && value >= 0) await state.setStock(id, value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    return Scaffold(
      // No sign-out here: it is in Settings, away from everyday buttons
      appBar: AppBar(title: Text(l.myMedicines)),
      body: ListView(
        children: [
          for (final m in state.active)
            ListTile(
              title: Text(m.label),
              isThreeLine: m.drugId != null,
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (m.asNeeded)
                        l.asNeeded
                      else
                        formatPattern(m.dosePattern ?? ''),
                      timingLabel(l, m.timing),
                      if (refillStatus(m, state.settings, state.wallNow)
                          case final r?)
                        l.daysLeft(
                          localDigits(context, formatDays(r.daysLeft)),
                        ),
                      if (m.durationDays != null)
                        localDigits(context, l.daysCount(m.durationDays!))
                      else
                        l.continueIndefinitely,
                    ].join(' · '),
                  ),
                  if (m.drugId != null) _PriceLine(medicine: m),
                ],
              ),
              onTap: () => _actions(context, m),
              // A word, not just an icon: what the button does must be clear
              trailing: TextButton(
                key: Key('stop-${m.id}'),
                onPressed: () => _stop(context, m.id, m.label),
                child: Text(l.stopShort),
              ),
            ),
        ],
      ),
    );
  }
}

/// "প্রতিটি আনুমানিক ৬ টাকা" and, when the catalogue has one, a link to cheaper brands of the
/// same medicine. Nothing is shown while loading or when the server cannot be reached.
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    return FutureBuilder<DrugAlternatives?>(
      future: state.alternativesFor(medicine),
      builder: (context, snap) {
        final result = snap.data;
        final price = result?.drug.unitPriceBdt;
        if (result == null || price == null) return const SizedBox.shrink();
        final taka = localDigits(context, formatTaka(price));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch ((result.drug.pack, result.pricesVerified)) {
              (final pack?, true) => l.pricePack(pack, taka),
              (final pack?, false) => l.pricePackApprox(pack, taka),
              (null, true) => l.priceEach(taka),
              (null, false) => l.priceEachApprox(taka),
            }),
            if (result.alternatives.isNotEmpty)
              TextButton(
                key: Key('cheaper-${medicine.id}'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => CheaperSheet(
                    medicine: medicine,
                    result: result,
                    settings: state.settings,
                  ),
                ),
                child: Text(
                  l.cheaperAvailable(
                    result.alternatives.first.drug.brand,
                    localDigits(
                      context,
                      result.alternatives.first.savingPercent,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Cheaper brands with what each would save, and the reminder to ask before switching.
class CheaperSheet extends StatelessWidget {
  const CheaperSheet({
    super.key,
    required this.medicine,
    required this.result,
    required this.settings,
  });

  final Medicine medicine;
  final DrugAlternatives result;
  final ScheduleSettings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final days = savingDays(medicine);
    final perDay = piecesPerDay(medicine, settings);
    final current = result.drug;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.cheaperTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l.cheaperIntro(current.generic, current.strength)),
            const SizedBox(height: 8),
            for (final a in result.alternatives)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(a.drug.label),
                subtitle: Text(
                  [
                    switch (a.drug.pack) {
                      final pack? => l.cheaperRowPack(
                        pack,
                        localDigits(context, formatTaka(a.drug.unitPriceBdt!)),
                        localDigits(context, a.savingPercent),
                      ),
                      null => l.cheaperRow(
                        localDigits(context, formatTaka(a.drug.unitPriceBdt!)),
                        localDigits(context, a.savingPercent),
                      ),
                    },
                    if (saving(
                          current: current,
                          cheaper: a.drug,
                          piecesPerDay: perDay,
                          days: days,
                        )
                        case final amount?)
                      days == 30
                          ? l.cheaperMonthly(
                              localDigits(context, amount.round()),
                            )
                          : l.cheaperCourse(
                              localDigits(context, amount.round()),
                            ),
                  ].join(' · '),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              l.cheaperDisclaimer,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!result.pricesVerified) ...[
              const SizedBox(height: 4),
              Text(l.pricesApproximate),
            ],
          ],
        ),
      ),
    );
  }
}
