import 'package:material_ui/material_ui.dart';

const _bnDigits = '০১২৩৪৫৬৭৮৯';

/// Bangla digits in Bangla text ("৭ দিনের জন্য ৫০টি"), so numbers do not switch script mid-sentence.
String localDigits(BuildContext context, Object value) {
  final text = '$value';
  if (Localizations.localeOf(context).languageCode != 'bn') return text;
  return text.replaceAllMapped(
    RegExp('[0-9]'),
    (m) => _bnDigits[int.parse(m[0]!)],
  );
}

/// A dose amount as it is written on prescriptions: "0.5" → "½", "1.5" → "1½".
String formatAmount(String amount) {
  final value = double.tryParse(amount);
  if (value == null) return amount;
  final whole = value.truncate();
  final fraction = switch (((value - whole) * 100).round()) {
    0 => '',
    25 => '¼',
    50 => '½',
    75 => '¾',
    _ => null,
  };
  if (fraction == null) return amount;
  if (whole == 0 && fraction.isNotEmpty) return fraction;
  return '$whole$fraction';
}

/// "0.5+0+0.5" → "½+0+½".
String formatPattern(String pattern) =>
    pattern.split('+').map(formatAmount).join('+');

/// Days left as people say it: "2" rather than "2.0", one decimal only below 10 days.
String formatDays(double days) {
  if (days >= 10 || days == days.roundToDouble()) return '${days.round()}';
  return days.toStringAsFixed(1);
}
