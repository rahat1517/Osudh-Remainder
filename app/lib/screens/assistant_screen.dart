import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../alarms/speaker.dart';
import '../assistant/voice_input.dart';
import '../data/assistant.dart';
import '../data/backend_api.dart';
import '../l10n/codes.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.voice,
    required this.speaker,
  });

  final VoiceInput voice;
  final Speaker speaker;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _turns = <ChatTurn>[];
  final _input = TextEditingController();
  final _done = <AssistantAction>{};
  bool _thinking = false;
  bool _listening = false;

  @override
  void dispose() {
    _input.dispose();
    widget.speaker.stop();
    super.dispose();
  }

  Future<void> _send([String? spoken]) async {
    final text = (spoken ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    final state = context.read<AppState>();
    final l = AppLocalizations.of(context);
    _input.clear();
    setState(() {
      _turns.add(ChatTurn(true, text));
      _thinking = true;
    });
    try {
      final reply = await state.api.askAssistant(
        _turns,
        assistantContext(
          medicines: state.active,
          settings: state.settings,
          now: DateTime.now(),
        ),
      );
      setState(
        () => _turns.add(
          ChatTurn(
            false,
            reply.text,
            actions: reply.actions,
            emergency: reply.emergency,
          ),
        ),
      );
      await widget.speaker.speak(reply.text);
    } on ApiException catch (e) {
      setState(
        () => _turns.add(
          ChatTurn(false, localizeError(l, e.code) ?? l.errorGeneric),
        ),
      );
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<void> _toggleVoice() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_listening) {
      await widget.voice.stop();
      setState(() => _listening = false);
      return;
    }
    await widget.speaker.stop();
    final ok = await widget.voice.start(
      onText: (text, isFinal) {
        _input.text = text;
        if (isFinal) {
          setState(() => _listening = false);
          _send(text);
        }
      },
    );
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.assistantVoiceUnavailable)),
      );
      return;
    }
    setState(() => _listening = true);
  }

  Future<void> _apply(AssistantAction a) async {
    final state = context.read<AppState>();
    if (a.type == AssistantActionType.stopMedicine) {
      await state.stop(a.medicineId!);
    } else {
      final parts = a.time!.split(':');
      await state.updateMealTime(
        a.meal!,
        int.parse(parts[0]) * 60 + int.parse(parts[1]),
      );
    }
    setState(() => _done.add(a));
  }

  String _actionText(AppLocalizations l, AssistantAction a) {
    if (a.type == AssistantActionType.stopMedicine) {
      final med = context.read<AppState>().active.where(
        (m) => m.id == a.medicineId,
      );
      return l.actionStop(med.isEmpty ? a.medicineId ?? '' : med.first.label);
    }
    final meal = switch (a.meal) {
      'breakfast' => l.mealBreakfast,
      'lunch' => l.mealLunch,
      'evening' => l.mealEvening,
      'dinner' => l.mealDinner,
      _ => l.mealBedtime,
    };
    return l.actionMealTime(meal, a.time ?? '');
  }

  Widget _bubble(ChatTurn t) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final emergency = t.emergency != null;
    return Align(
      alignment: t.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: emergency
              ? scheme.errorContainer
              : t.fromUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.text, style: Theme.of(context).textTheme.bodyLarge),
            if (emergency) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('call999'),
                style: FilledButton.styleFrom(backgroundColor: scheme.error),
                onPressed: () => launchUrl(Uri.parse('tel:999')),
                icon: const Icon(Icons.call),
                label: Text(l.call999),
              ),
            ],
            for (final a in t.actions)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _actionText(l, a),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_done.contains(a))
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle),
                            const SizedBox(width: 6),
                            Text(l.actionDone),
                          ],
                        )
                      else
                        FilledButton(
                          key: const Key('confirmAction'),
                          onPressed: () => _apply(a),
                          child: Text(l.actionConfirm),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.assistantTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l.assistantIntro,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                for (final t in _turns) _bubble(t),
                if (_thinking)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    key: const Key('mic'),
                    iconSize: 32,
                    onPressed: _toggleVoice,
                    icon: Icon(_listening ? Icons.stop : Icons.mic),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('question'),
                      controller: _input,
                      decoration: InputDecoration(
                        hintText: _listening
                            ? l.assistantListening
                            : l.assistantHint,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    key: const Key('send'),
                    onPressed: () => _send(),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
