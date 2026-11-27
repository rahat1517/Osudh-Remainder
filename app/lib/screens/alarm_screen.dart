import 'package:material_ui/material_ui.dart';

import '../l10n/format.dart';
import '../alarms/alarm_payload.dart';
import '../alarms/alarm_service.dart';
import '../alarms/dose_log.dart';
import '../alarms/speaker.dart';
import '../l10n/generated/app_localizations.dart';
import 'home_screen.dart' show formatClock;

/// Full-screen alarm, shown over the lock screen when a dose is due.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({
    super.key,
    required this.payload,
    required this.service,
    required this.speaker,
  });

  final AlarmPayload payload;
  final AlarmService service;
  final Speaker speaker;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _busy = false;
  bool _spoken = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_spoken) {
      _spoken = true;
      final names = widget.payload.items.map((i) => i.label).join(', ');
      widget.speaker.speak(AppLocalizations.of(context).alarmSpeech(names));
    }
  }

  @override
  void dispose() {
    widget.speaker.stop();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _busy = true);
    await widget.speaker.stop();
    await action();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _snooze() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.service.snooze(widget.payload);
    if (result == SnoozeResult.limitReached) {
      messenger.showSnackBar(SnackBar(content: Text(l.snoozeLimit)));
      setState(() => _busy = false);
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final big = theme.textTheme.headlineSmall;
    return Scaffold(
      backgroundColor: theme.colorScheme.primaryContainer,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.alarm, size: 72, color: theme.colorScheme.primary),
              Text(
                formatClock(widget.payload.at),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium,
              ),
              Text(l.alarmTitle, textAlign: TextAlign.center, style: big),
              const SizedBox(height: 24),
              for (final item in widget.payload.items)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.medication, size: 36),
                    title: Text(item.label, style: big),
                    trailing: Text(
                      '× ${formatAmount(item.amount)}',
                      style: big,
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('taken'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(72),
                ),
                onPressed: _busy
                    ? null
                    : () => _act(
                        () => widget.service.record(
                          widget.payload,
                          DoseStatus.taken,
                        ),
                      ),
                icon: const Icon(Icons.check_circle, size: 32),
                label: Text(l.alarmTaken),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('snooze'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                      ),
                      onPressed: _busy ? null : _snooze,
                      child: Text(l.alarmSnooze),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('skip'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _act(
                              () => widget.service.record(
                                widget.payload,
                                DoseStatus.skipped,
                              ),
                            ),
                      child: Text(l.alarmSkip),
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
}
