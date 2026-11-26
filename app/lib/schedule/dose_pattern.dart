/// Dose pattern parsing ("1+0+1", "½+০+½", "1-0-1").
///
/// Mirrors `backend/app/prescriptions/dose.py`; see docs/SCHEDULE_SPEC.md §3.1.
library;

const _banglaDigits = {
  '০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4', //
  '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9',
};
const _fractionSymbols = {'½': '0.5', '¼': '0.25', '¾': '0.75'};
final _separators = RegExp(r'\s*[+\-–—]\s*');
final _decimal = RegExp(r'^(\d+(\.\d*)?|\.\d+)$');
final _ratio = RegExp(r'^(\d+)/(\d+)$');

/// Maximum units per slot considered realistic.
const maxUnitsPerSlot = 4.0;

double? _parseAmount(String token) {
  var t = token.trim();
  _fractionSymbols.forEach((sym, dec) => t = t.replaceAll(sym, dec));
  double value;
  final ratio = _ratio.firstMatch(t);
  if (ratio != null) {
    final den = int.parse(ratio.group(2)!);
    if (den == 0) return null;
    value = int.parse(ratio.group(1)!) / den;
  } else if (_decimal.hasMatch(t)) {
    value = double.parse(t);
  } else {
    return null;
  }
  if (value < 0 || value > maxUnitsPerSlot) return null;
  return value;
}

/// Formats an amount like Python's `%g`: "1", "0.5", "0.333333".
String formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  var s = value.toStringAsPrecision(6);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Returns the amounts per slot, or null if the pattern is invalid.
List<double>? parseDosePattern(String? pattern) {
  if (pattern == null || pattern.trim().isEmpty) return null;
  var text = pattern.trim();
  _banglaDigits.forEach((bn, ascii) => text = text.replaceAll(bn, ascii));
  final parts = text.split(_separators);
  if (parts.length < 2 || parts.length > 4) return null;
  final amounts = <double>[];
  for (final p in parts) {
    final a = _parseAmount(p);
    if (a == null) return null;
    amounts.add(a);
  }
  if (amounts.every((a) => a == 0)) return null;
  return amounts;
}

/// Canonical form ("1+0+0.5"), or null if invalid.
String? normalizeDosePattern(String? pattern) =>
    parseDosePattern(pattern)?.map(formatAmount).join('+');
