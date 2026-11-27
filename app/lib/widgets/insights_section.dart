import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../insights/insights.dart';
import '../l10n/format.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';

String clockLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String mealLabel(AppLocalizations l, String meal) => switch (meal) {
  'breakfast' => l.mealBreakfast,
  'lunch' => l.mealLunch,
  'evening' => l.mealEvening,
  'dinner' => l.mealDinner,
  _ => l.mealBedtime,
};

/// Suggestions and warnings on the home screen. Nothing changes without the user's "Yes".
class InsightsSection extends StatefulWidget {
  const InsightsSection({super.key});

  @override
  State<InsightsSection> createState() => _InsightsSectionState();
}

class _InsightsSectionState extends State<InsightsSection> {
  final _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final cards = <Widget>[];

    for (final g in duplicateTherapies(state.active)) {
      cards.add(
        Card(
          color: scheme.errorContainer,
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
      );
    }
    for (final low in state.lowStock()) {
      cards.add(
        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l.lowStockTitle),
            subtitle: Text(
              l.lowStockBody(
                low.medicine.label,
                // Only the number: the medicine label keeps its own digits ("20 mg")
                localDigits(context, formatDays(low.status.daysLeft)),
              ),
            ),
          ),
        ),
      );
    }
    for (final s in state.mealShiftSuggestions()) {
      final key = '${s.meal}:${s.to}';
      if (_dismissed.contains(key)) continue;
      final meal = mealLabel(l, s.meal);
      cards.add(
        Card(
          key: Key('shift-${s.meal}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.mealShiftTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l.mealShiftBody(s.days, meal, clockLabel(s.to))),
                const SizedBox(height: 8),
                // The theme's buttons are full-width; share the row instead
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _dismissed.add(key)),
                        child: Text(l.no),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('acceptShift'),
                        onPressed: () async {
                          await state.updateMealTime(s.meal, s.to);
                          setState(() => _dismissed.add(key));
                        },
                        child: Text(l.yes),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cards,
    );
  }
}
