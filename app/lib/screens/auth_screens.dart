import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/auth_repository.dart';
import '../data/phone.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _phone = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final phone = normalizeBdPhone(_phone.text);
    if (phone == null) return setState(() => _error = l.phoneInvalid);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().auth.sendCode(phone);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => OtpScreen(phone: phone)));
    } on AuthException {
      setState(() => _error = l.authSmsFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.phoneTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: InputDecoration(
                hintText: l.phoneHint,
                errorText: _error,
                prefixText: '+88 ',
              ),
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: Text(l.sendCode),
            ),
          ],
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _verify() async {
    final state = context.read<AppState>();
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.auth.verifyCode(widget.phone, _code.text.trim());
      await state.refresh();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException {
      setState(() => _error = l.authInvalidCode);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final demo = context.read<AppState>().auth is DemoAuthRepository;
    return Scaffold(
      appBar: AppBar(title: Text(l.otpTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.otpSubtitle(widget.phone)),
            if (demo) Text(l.demoModeHint(DemoAuthRepository.demoCode)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('code'),
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              // Lets Android's SMS autofill offer the code
              autofillHints: const [AutofillHints.oneTimeCode],
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: InputDecoration(errorText: _error),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: Text(l.verify),
            ),
          ],
        ),
      ),
    );
  }
}
