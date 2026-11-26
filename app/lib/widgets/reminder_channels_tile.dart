import 'package:material_ui/material_ui.dart';

import '../data/reminder_channels.dart';
import '../l10n/generated/app_localizations.dart';

/// Switches for SMS/call reminders, used in settings (own) and on a caregiver's patient dashboard.
class ReminderChannelsTile extends StatefulWidget {
  const ReminderChannelsTile({
    super.key,
    required this.repository,
    required this.patientId,
    this.showFeaturePhone = false,
  });

  final ReminderChannelsRepository repository;
  final String patientId;
  final bool showFeaturePhone;

  @override
  State<ReminderChannelsTile> createState() => _ReminderChannelsTileState();
}

class _ReminderChannelsTileState extends State<ReminderChannelsTile> {
  ReminderChannels? _channels;

  @override
  void initState() {
    super.initState();
    widget.repository.load(widget.patientId).then((c) {
      if (mounted) setState(() => _channels = c);
    });
  }

  Future<void> _set(ReminderChannels c) async {
    setState(() => _channels = c);
    await widget.repository.save(widget.patientId, c);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = _channels;
    if (c == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l.channelsHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        SwitchListTile(
          key: const Key('smsSwitch'),
          title: Text(l.channelSms),
          value: c.sms,
          onChanged: (v) => _set(c.copyWith(sms: v)),
        ),
        SwitchListTile(
          key: const Key('callSwitch'),
          title: Text(l.channelCall),
          value: c.call,
          onChanged: (v) => _set(c.copyWith(call: v)),
        ),
        if (widget.showFeaturePhone)
          SwitchListTile(
            key: const Key('featurePhoneSwitch'),
            title: Text(l.featurePhoneMode),
            subtitle: Text(l.featurePhoneHelp),
            value: c.featurePhone,
            onChanged: (v) =>
                _set(c.copyWith(featurePhone: v, sms: v ? true : c.sms)),
          ),
      ],
    );
  }
}
