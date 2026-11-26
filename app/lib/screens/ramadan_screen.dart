import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../insights/prayer_times.dart';
import '../insights/ramadan.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/insights_section.dart' show clockLabel;

const _districtNames = {
  'dhaka': 'ঢাকা / Dhaka',
  'chattogram': 'চট্টগ্রাম / Chattogram',
  'sylhet': 'সিলেট / Sylhet',
  'rajshahi': 'রাজশাহী / Rajshahi',
  'khulna': 'খুলনা / Khulna',
  'barishal': 'বরিশাল / Barishal',
  'rangpur': 'রংপুর / Rangpur',
  'mymensingh': 'ময়মনসিংহ / Mymensingh',
};

class RamadanScreen extends StatefulWidget {
  const RamadanScreen({super.key});

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  late String _district = context.read<AppState>().store?.district ?? 'dhaka';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final store = state.store;
    final on = store?.ramadanBackup() != null;
    final now = state.wallNow;
    final plan = planRamadan(
      date: DateTime(now.year, now.month, now.day),
      district: districtByKey(_district),
      current: store?.ramadanBackup() ?? state.settings,
      medicines: state.active,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.ramadanTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.ramadanIntro),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _district,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.ramadanDistrict),
            items: [
              for (final d in districts)
                DropdownMenuItem(
                  value: d.key,
                  child: Text(_districtNames[d.key]!),
                ),
            ],
            onChanged: (v) {
              setState(() => _district = v!);
              store?.setDistrict(v!);
            },
          ),
          const SizedBox(height: 12),
          Text(
            l.ramadanTimes(clockLabel(plan.sehriEnds), clockLabel(plan.iftar)),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${l.mealBreakfast}: ${clockLabel(plan.settings.breakfast)} · ${l.mealDinner}: ${clockLabel(plan.settings.dinner)}',
          ),
          if (plan.fastingConflicts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${l.ramadanConflicts}\n${plan.fastingConflicts.map((m) => '• ${m.label}').join('\n')}',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('ramadanToggle'),
            onPressed: store == null
                ? null
                : () async {
                    if (on) {
                      final backup = store.ramadanBackup()!;
                      await state.applySettings(backup);
                      await store.clearRamadanBackup();
                    } else {
                      await store.saveRamadanBackup(state.settings);
                      await state.applySettings(plan.settings);
                    }
                    setState(() {});
                  },
            child: Text(on ? l.ramadanOff : l.ramadanOn),
          ),
        ],
      ),
    );
  }
}
