/// The home-screen widget: the next dose and a "Taken" button, without opening the app.
///
/// The phone draws the widget itself (DoseWidgetProvider.kt), possibly hours after the app last
/// ran, so this writes a short list of upcoming doses with every time already worked out; the
/// widget shows the first one not yet over. Updates are scheduled for the moments the picture
/// changes (a dose becomes due, or its time is over).
library;

import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../data/models.dart';
import '../l10n/format.dart';
import '../l10n/generated/app_localizations.dart';
import '../schedule/schedule_models.dart';
import '../alarms/alarm_payload.dart';
import '../alarms/alarm_planner.dart';

/// Key of the snapshot in the widget's storage; read by DoseWidgetProvider.kt.
const widgetDataKey = 'dose_widget_v1';
const widgetProvider = 'com.oshudh.oshudh_reminder.DoseWidgetProvider';

/// A dose is shown as due (with the "Taken" button) from this long before its time...
const dueEarly = Duration(minutes: 30);

/// ...until this long after; then the widget moves on to the next one. Matches how long a dose
/// alarm can still be answered in practice (it rings for 10 minutes, snoozes up to 30).
const dueFor = Duration(minutes: 60);

/// Uri of the "Taken" button: `oshudh://taken?payload=<alarm payload>`.
Uri takenUri(AlarmSpec spec) => Uri(
  scheme: 'oshudh',
  host: 'taken',
  queryParameters: {'payload': AlarmPayload.fromSpec(spec).encode()},
);

const _bnDigits = '০১২৩৪৫৬৭৮৯';
String _bn(String s) =>
    s.replaceAllMapped(RegExp('[0-9]'), (m) => _bnDigits[int.parse(m[0]!)]);

/// The widget's data. Pure: [wallNow] is the user's wall clock (UTC container).
Map<String, Object?> buildWidgetSnapshot({
  required List<Medicine> medicines,
  required ScheduleSettings settings,
  required DateTime wallNow,
  required Set<String> handledKeys,
  required AppLocalizations l,
  Duration utcOffset = const Duration(hours: 6),
  int maxEntries = 12,
}) {
  final specs = planAlarms(
    medicines: medicines,
    settings: settings,
    // Include doses whose time has just passed: they are still due
    wallNow: wallNow.subtract(dueFor),
    handledKeys: handledKeys,
    utcOffset: utcOffset,
    horizonDays: 2,
  ).where((a) => !a.isNotice).take(maxEntries);

  int instant(DateTime wall) => wall.subtract(utcOffset).millisecondsSinceEpoch;

  return {
    'entries': [
      for (final a in specs)
        {
          'at': instant(a.at),
          'dueFrom': instant(a.at.subtract(dueEarly)),
          'until': instant(a.at.add(dueFor)),
          'dayStart': instant(DateTime.utc(a.at.year, a.at.month, a.at.day)),
          'time': _bn(
            '${a.at.hour.toString().padLeft(2, '0')}:'
            '${a.at.minute.toString().padLeft(2, '0')}',
          ),
          // The name and strength as on the packet ("Napa 500 mg"); the amount in Bangla
          'medicines': a.items
              .map((i) => '${i.label} × ${_bn(formatAmount(i.amount))}')
              .join('\n'),
          'takenUri': takenUri(a).toString(),
        },
    ],
    'texts': {
      'next': l.widgetNext,
      'due': l.widgetDue,
      'taken': l.alarmTaken,
      'tomorrow': l.widgetTomorrow,
      'empty': medicines.isEmpty ? l.widgetNoMedicines : l.widgetOpenApp,
    },
  };
}

/// When the widget must be redrawn: each dose becoming due and each dose's time running out.
List<DateTime> widgetRefreshTimes(Map<String, Object?> snapshot, DateTime now) {
  final times = <DateTime>{};
  for (final e in snapshot['entries']! as List) {
    for (final key in const ['dueFrom', 'until']) {
      final t = DateTime.fromMillisecondsSinceEpoch(
        (e as Map)[key] as int,
        isUtc: true,
      );
      if (t.isAfter(now)) times.add(t);
    }
  }
  return times.toList()..sort();
}

/// Where the snapshot goes; a fake in tests.
abstract interface class WidgetPublisher {
  Future<void> publish(Map<String, Object?> snapshot, List<DateTime> refreshAt);
}

class HomeWidgetPublisher implements WidgetPublisher {
  @override
  Future<void> publish(
    Map<String, Object?> snapshot,
    List<DateTime> refreshAt,
  ) async {
    await HomeWidget.saveWidgetData<String>(
      widgetDataKey,
      jsonEncode(snapshot),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: widgetProvider);
    await HomeWidget.scheduleWidgetUpdates(
      refreshAt,
      qualifiedAndroidName: widgetProvider,
    );
  }
}

class FakeWidgetPublisher implements WidgetPublisher {
  Map<String, Object?>? snapshot;
  List<DateTime> refreshAt = const [];
  int publishes = 0;

  @override
  Future<void> publish(
    Map<String, Object?> snapshot,
    List<DateTime> refreshAt,
  ) async {
    this.snapshot = snapshot;
    this.refreshAt = refreshAt;
    publishes++;
  }
}

/// Keeps the widget in step with the alarms (called after every alarm sync).
class DoseWidget {
  DoseWidget(this.publisher, this.l10n);

  final WidgetPublisher publisher;
  final AppLocalizations l10n;

  /// Never throws: the widget must never get in the way of the alarms.
  Future<void> update({
    required List<Medicine> medicines,
    required ScheduleSettings settings,
    required DateTime wallNow,
    required Set<String> handledKeys,
    required DateTime now,
    Duration utcOffset = const Duration(hours: 6),
  }) async {
    try {
      final snapshot = buildWidgetSnapshot(
        medicines: medicines,
        settings: settings,
        wallNow: wallNow,
        handledKeys: handledKeys,
        l: l10n,
        utcOffset: utcOffset,
      );
      await publisher.publish(snapshot, widgetRefreshTimes(snapshot, now));
    } on Object {
      // No launcher widget support, or no widget placed: nothing to update
    }
  }
}
