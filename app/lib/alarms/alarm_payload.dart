import 'dart:convert';

import '../schedule/schedule_models.dart';
import 'alarm_planner.dart';

/// Data carried inside a notification, so an alarm can be handled with the app closed.
class AlarmPayload {
  const AlarmPayload(this.at, this.items, {this.notificationId});

  factory AlarmPayload.fromSpec(AlarmSpec s) =>
      AlarmPayload(s.doseAt ?? s.at, s.items, notificationId: s.id);

  /// The notification showing this alarm, so it can be removed (and its sound stopped) once the
  /// user answers it in the app.
  final int? notificationId;

  factory AlarmPayload.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return AlarmPayload(DateTime.parse('${j['at']}Z'), [
      for (final i in j['items'] as List)
        AlarmItem(
          i['id'] as String,
          i['label'] as String,
          i['amount'] as String,
          timing: _timing(i['timing']),
        ),
    ], notificationId: j['nid'] as int?);
  }

  /// Wall-clock time the doses were scheduled for.
  final DateTime at;
  final List<AlarmItem> items;

  /// Identifies this reminder for snooze counting.
  String get reminderKey =>
      '${at.toIso8601String().substring(0, 16)}|${items.map((i) => i.medicineId).join(',')}';

  String encode() => jsonEncode({
    'at': at.toIso8601String().substring(0, 19),
    'nid': ?notificationId,
    'items': [
      for (final i in items)
        {
          'id': i.medicineId,
          'label': i.label,
          'amount': i.amount,
          'timing': ?_timingJson[i.timing],
        },
    ],
  });
}

const _timingJson = {
  Timing.beforeMeal: 'before_meal',
  Timing.afterMeal: 'after_meal',
  Timing.withMeal: 'with_meal',
  Timing.emptyStomach: 'empty_stomach',
  Timing.bedtime: 'bedtime',
  Timing.notSpecified: 'not_specified',
};

Timing? _timing(Object? value) {
  if (value is! String) return null; // older payloads have none
  try {
    return timingFromJson(value);
  } on ArgumentError {
    return null;
  }
}
