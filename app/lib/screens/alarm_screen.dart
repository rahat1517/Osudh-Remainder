import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/format.dart';
import '../alarms/alarm_payload.dart';
import '../alarms/alarm_service.dart';
import '../alarms/dose_log.dart';
import '../alarms/alarm_scheduler.dart' show ringFor;
import '../alarms/speaker.dart';
import '../alarms/voice.dart';
import '../l10n/generated/app_localizations.dart';
import 'home_screen.dart' show formatClock;

/// Full-screen alarm, shown over the lock screen when a dose is due.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({
    super.key,
    required this.payload,
    required this.service,
    required this.speaker,
    VoicePlayer? voice,
    this.repeatEvery = const Duration(seconds: 4),
  }) : _voice = voice;

  final AlarmPayload payload;
  final AlarmService service;

  /// The phone's text-to-speech, used when there is no recording.
  final Speaker speaker;
  final VoicePlayer? _voice;

  /// Pause between repeats of the spoken reminder while nobody has answered.
  final Duration repeatEvery;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _busy = false;
  bool _started = false;
  Timer? _next;
  late final VoicePlayer _voice = widget._voice ?? AssetVoicePlayer();
  late final DateTime _until = DateTime.now().add(ringFor);

  bool get _isTest =>
      widget.payload.items.any((i) => i.medicineId == testAlarmMedicineId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // The screen now does the reminding (the recorded voice, repeated): stop the ringing
    // notification so the two do not play over each other
    unawaited(widget.service.dismiss(widget.payload));
    unawaited(_announce());
  }

  /// Says the reminder, then again every few seconds until a button is pressed (up to [ringFor]).
  Future<void> _announce() async {
    if (!mounted || _busy || DateTime.now().isAfter(_until)) return;
    final again =
        widget.service.store.snoozeCount(widget.payload.reminderKey) > 0;
    final clip = _isTest
        ? VoiceClip.testAlarm
        : again
        ? VoiceClip.reminderAgain
        : VoiceClip.alarmOpen;
    var played = await _voice.play(clip);
    if (!played && clip != VoiceClip.alarmOpen) {
      played = await _voice.play(VoiceClip.alarmOpen);
    }
    if (!played && mounted) {
      final names = widget.payload.items.map((i) => i.label).join(', ');
      await widget.speaker.speak(
        AppLocalizations.of(context).alarmSpeech(names),
      );
    }
    if (!mounted || _busy) return;
    _next = Timer(widget.repeatEvery, _announce);
  }

  @override
  void dispose() {
    _next?.cancel();
    widget.speaker.stop();
    _voice.stop();
    super.dispose();
  }

  Future<void> _quiet() async {
    _next?.cancel();
    await widget.speaker.stop();
    await _voice.stop();
  }

  Future<void> _act(Future<void> Function() action, VoiceClip reply) async {
    setState(() => _busy = true);
    await _quiet();
    await action();
    await _voice.play(reply); // "ধন্যবাদ..." etc.; nothing if not recorded
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _snooze() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    await _quiet();
    final result = await widget.service.snooze(widget.payload);
    if (result == SnoozeResult.limitReached) {
      messenger.showSnackBar(SnackBar(content: Text(l.snoozeLimit)));
      setState(() => _busy = false);
      unawaited(_announce());
      return;
    }
    await _voice.play(VoiceClip.snoozed);
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
                      '×\u00A0${formatAmount(item.amount)}',
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
                        VoiceClip.taken,
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
                              VoiceClip.skipped,
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
