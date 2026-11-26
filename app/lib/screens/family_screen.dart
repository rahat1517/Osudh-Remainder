import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../caregivers/caregiver_models.dart';
import '../caregivers/caregiver_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import 'patient_dashboard_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<CaregiverLink> _links = const [];
  final _code = TextEditingController();
  String? _codeError;

  CaregiverRepository get _repo => context.read<AppState>().caregivers!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final links = await _repo.links();
    if (mounted) setState(() => _links = links);
  }

  Future<void> _invite(CaregiverPermission permission) async {
    final l = AppLocalizations.of(context);
    final code = await _repo.createInvite(permission);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.inviteCodeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              code,
              key: const Key('inviteCode'),
              style: Theme.of(ctx).textTheme.displaySmall
                  ?.copyWith(letterSpacing: 4),
            ),
            const SizedBox(height: 12),
            Text(l.inviteCodeHelp),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: l.shareCode(code))),
            icon: const Icon(Icons.copy),
            label: Text(MaterialLocalizations.of(ctx).copyButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    final l = AppLocalizations.of(context);
    try {
      await _repo.acceptInvite(_code.text);
      _code.clear();
      setState(() => _codeError = null);
      await _load();
    } on CaregiverException catch (e) {
      setState(
        () =>
            _codeError = e.code == 'invite_own' ? l.inviteOwn : l.inviteInvalid,
      );
    }
  }

  Future<void> _revoke(CaregiverLink link, String name) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.revokeConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.revoke),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await _repo.revoke(link.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = context.read<AppState>().auth.currentUserId;
    final caregivers = _links.where((x) => x.patientId == me).toList();
    final patients = _links.where((x) => x.caregiverId == me).toList();
    final heading = Theme.of(context).textTheme.titleLarge;
    return Scaffold(
      appBar: AppBar(title: Text(l.familyTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.familyIntro),
            const SizedBox(height: 16),
            Text(l.inviteCaregiver, style: heading),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.visibility),
                    title: Text(l.permissionView),
                    onTap: () => _invite(CaregiverPermission.view),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: Text(l.permissionEdit),
                    onTap: () => _invite(CaregiverPermission.edit),
                  ),
                ],
              ),
            ),
            for (final c in caregivers)
              ListTile(
                leading: const Icon(Icons.family_restroom),
                title: Text(c.caregiverName ?? l.unnamedPerson),
                subtitle: Text(
                  c.permission == CaregiverPermission.edit
                      ? l.permissionEdit
                      : l.permissionView,
                ),
                trailing: IconButton(
                  tooltip: l.revoke,
                  icon: const Icon(Icons.person_remove),
                  onPressed: () =>
                      _revoke(c, c.caregiverName ?? l.unnamedPerson),
                ),
              ),
            const Divider(height: 32),
            Text(l.iAmCaregiver, style: heading),
            TextField(
              key: const Key('inviteInput'),
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.enterInviteCode,
                errorText: _codeError,
              ),
              onSubmitted: (_) => _accept(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('acceptInvite'),
              onPressed: _accept,
              child: Text(l.acceptInvite),
            ),
            const SizedBox(height: 16),
            Text(l.peopleICareFor, style: heading),
            if (patients.isEmpty) Text(l.noLinks),
            for (final p in patients)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.elderly),
                  title: Text(p.patientName ?? l.unnamedPerson),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PatientDashboardScreen(link: p),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
