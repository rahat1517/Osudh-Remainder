import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../caregivers/caregiver_models.dart';
import '../caregivers/dashboard.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/reminder_channels_tile.dart';
import 'confirm_screen.dart';
import 'home_screen.dart' show formatClock;

/// A caregiver's view of one patient's doses today.
class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key, required this.link});

  final CaregiverLink link;

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  PatientSnapshot? _patient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final p = await state.caregivers!.patient(
      widget.link.patientId,
      since: DateTime.now().toUtc().subtract(const Duration(days: 2)),
    );
    if (mounted) setState(() => _patient = p);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = _patient;
    final rows = p == null
        ? const <DoseRow>[]
        : todaysDoses(p, context.read<AppState>().wallNow);
    (String, Color, IconData) look(DoseState s) => switch (s) {
      DoseState.taken => (
        l.stateTaken,
        Colors.green.shade700,
        Icons.check_circle,
      ),
      DoseState.skipped => (
        l.stateSkipped,
        scheme.outline,
        Icons.remove_circle_outline,
      ),
      DoseState.missed => (l.stateMissed, scheme.error, Icons.error),
      DoseState.due => (l.stateDue, Colors.orange.shade800, Icons.alarm),
      DoseState.upcoming => (
        l.stateUpcoming,
        scheme.onSurfaceVariant,
        Icons.schedule,
      ),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.name ?? widget.link.patientName ?? l.unnamedPerson),
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.link.permission == CaregiverPermission.edit &&
                      context.read<AppState>().channels != null)
                    Card(
                      child: ReminderChannelsTile(
                        repository: context.read<AppState>().channels!,
                        patientId: widget.link.patientId,
                        showFeaturePhone: true,
                      ),
                    ),
                  if (rows.isEmpty) Text(l.dashboardEmpty),
                  for (final r in rows)
                    Card(
                      child: ListTile(
                        leading: Text(
                          formatClock(r.at),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        title: Text(
                          '${r.label}\u00A0×\u00A0${formatAmount(r.amount)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(look(r.state).$3, color: look(r.state).$2),
                            const SizedBox(width: 6),
                            Text(
                              look(r.state).$1,
                              style: TextStyle(color: look(r.state).$2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: widget.link.permission == CaregiverPermission.edit
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ConfirmScreen.manual(forUserId: widget.link.patientId),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l.addForPatient),
            )
          : null,
    );
  }
}
