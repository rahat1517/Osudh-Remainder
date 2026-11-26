import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../alarms/alarm_runtime.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import 'confirm_screen.dart';
import 'family_screen.dart';
import 'medicines_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

String formatClock(DateTime wall) =>
    '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final reminders = state.todaysReminders();
    final next = state.nextReminder();
    final now = state.wallNow;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: [
          IconButton(
            tooltip: l.setupTitle,
            icon: const Icon(Icons.alarm),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SetupScreen(notifications: notificationsPlugin),
              ),
            ),
          ),
          if (state.caregivers != null)
            IconButton(
              tooltip: l.familyTitle,
              icon: const Icon(Icons.family_restroom),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const FamilyScreen()),
              ),
            ),
          IconButton(
            tooltip: l.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: l.myMedicines,
            icon: const Icon(Icons.medication_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MedicinesScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: reminders.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  Text(
                    l.homeEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.offline)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_off),
                        title: Text(l.offlineNotice),
                      ),
                    ),
                  if (state.scheduledAlarms > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l.remindersScheduled(state.scheduledAlarms)),
                    ),
                  for (final r in reminders)
                    Card(
                      color: identical(r, next)
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        leading: Text(
                          formatClock(r.at),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        title: Text(
                          r.items
                              .map((i) => '${i.medicine.label} × ${i.amount}')
                              .join('\n'),
                        ),
                        trailing: r.at == next?.at
                            ? Chip(label: Text(l.nextDose))
                            : r.at.isBefore(now)
                            ? Text(l.done)
                            : null,
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'manual',
            tooltip: l.addManually,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ConfirmScreen.manual()),
            ),
            child: const Icon(Icons.edit),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const ScanScreen())),
            icon: const Icon(Icons.document_scanner),
            label: Text(l.scanPrescription),
          ),
        ],
      ),
    );
  }
}
