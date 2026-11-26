import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../insights/insights.dart';
import '../l10n/generated/app_localizations.dart';
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
          decoration: InputDecoration(helperText: l.stockHelp),
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
      appBar: AppBar(
        title: Text(l.myMedicines),
        actions: [
          IconButton(
            tooltip: l.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await state.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final m in state.active)
            ListTile(
              title: Text(m.label),
              subtitle: Text(
                [
                  if (m.asNeeded) l.asNeeded else m.dosePattern ?? '',
                  timingLabel(l, m.timing),
                  if (refillStatus(m, state.settings, state.wallNow)
                      case final r?)
                    l.daysLeft(r.daysLeft.toStringAsFixed(1)),
                  if (m.durationDays != null)
                    '${m.durationDays} ${l.fieldDuration}'
                  else
                    l.continueIndefinitely,
                ].join(' · '),
              ),
              onTap: () => _stock(context, m.id, m.pillsOnHand),
              trailing: IconButton(
                tooltip: l.stopMedicine,
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: () => _stop(context, m.id, m.label),
              ),
            ),
        ],
      ),
    );
  }
}
