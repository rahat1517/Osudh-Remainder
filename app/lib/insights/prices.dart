/// What a cheaper brand of the same medicine would save. Pure functions.
library;

import '../data/models.dart';
import '../schedule/schedule_engine.dart';
import '../schedule/schedule_models.dart';

/// Forms priced per piece; liquids are priced per bottle, so a daily amount says nothing.
bool pricedPerPiece(String form) =>
    RegExp(r'tablet|capsule|sachet', caseSensitive: false).hasMatch(form);

/// Pieces taken per day on the medicine's schedule (0 for "as needed").
double piecesPerDay(
  Medicine m,
  ScheduleSettings settings, {
  Duration utcOffset = const Duration(hours: 6),
}) {
  final perDay = dailyTimes(
    m.toScheduleInput(utcOffset: utcOffset),
    settings,
  ).fold<double>(0, (s, t) => s + double.parse(t.amount));
  final weekdays = m.weekdays;
  if (weekdays != null && weekdays.isNotEmpty) {
    return perDay * weekdays.length / 7;
  }
  return perDay;
}

/// Taka saved over [days] by taking [cheaper] instead of [current]; null when it cannot be
/// worked out (no prices, a liquid, or taken only when needed).
double? saving({
  required Drug current,
  required Drug cheaper,
  required double piecesPerDay,
  required int days,
}) {
  final a = current.unitPriceBdt, b = cheaper.unitPriceBdt;
  if (a == null || b == null || b >= a || piecesPerDay <= 0) return null;
  if (!pricedPerPiece(current.form) || !pricedPerPiece(cheaper.form)) {
    return null;
  }
  return (a - b) * piecesPerDay * days;
}

/// Days to show a saving for: a month, or the whole course when it is shorter.
int savingDays(Medicine m) {
  final d = m.durationDays;
  return d != null && d < 30 ? d : 30;
}

/// "6", "1.20", "35": whole taka without decimals, otherwise two.
String formatTaka(double value) {
  final rounded = (value * 100).round() / 100;
  return rounded == rounded.roundToDouble()
      ? '${rounded.round()}'
      : rounded.toStringAsFixed(2);
}
