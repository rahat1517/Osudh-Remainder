import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/codes.dart';
import '../l10n/generated/app_localizations.dart';
import '../schedule/schedule_models.dart';
import '../state/app_state.dart';

/// Meal and bed times, which every reminder is calculated from. Changing one moves its reminders.
class MealTimesTile extends StatelessWidget {
  const MealTimesTile({super.key});

  static String _clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final s = state.settings;
    final meals = [
      (
        'breakfast',
        l.mealBreakfast,
        s.breakfast,
        Icons.free_breakfast_outlined,
      ),
      ('lunch', l.mealLunch, s.lunch, Icons.lunch_dining_outlined),
      ('evening', l.mealEvening, s.evening, Icons.bakery_dining_outlined),
      ('dinner', l.mealDinner, s.dinner, Icons.dinner_dining_outlined),
      ('bedtime', l.mealBedtime, s.bedtime, Icons.bedtime_outlined),
    ];

    Future<void> pick(String meal, int current) async {
      final messenger = ScaffoldMessenger.of(context);
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      );
      if (picked == null) return;
      try {
        await state.updateMealTime(meal, picked.hour * 60 + picked.minute);
      } on ScheduleException catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(localizeError(l, e.code) ?? e.message)),
        );
      } on Exception {
        messenger.showSnackBar(SnackBar(content: Text(l.mealTimesSaveFailed)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(
            l.mealTimesTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(l.mealTimesHelp),
        ),
        for (final (meal, label, minutes, icon) in meals)
          ListTile(
            key: Key('meal-$meal'),
            leading: Icon(icon),
            title: Text(label),
            trailing: Text(
              _clock(minutes),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => pick(meal, minutes),
          ),
      ],
    );
  }
}
