/// What the user did when a dose was due.
library;

enum DoseStatus { taken, skipped }

String _wallIso(DateTime wall) => wall.toIso8601String().substring(0, 16);

/// Identifies one scheduled dose: a medicine at a wall-clock time.
String doseKey(String medicineId, DateTime scheduledWall) =>
    '$medicineId@${_wallIso(scheduledWall)}';

class DoseLog {
  const DoseLog({
    required this.medicineId,
    required this.scheduledAt,
    required this.status,
    required this.actedAt,
    this.synced = false,
  });

  factory DoseLog.fromJson(Map<String, dynamic> j) => DoseLog(
    medicineId: j['medicine_id'] as String,
    scheduledAt: DateTime.parse('${j['scheduled_at']}Z'),
    status: DoseStatus.values.byName(j['status'] as String),
    actedAt: DateTime.parse(j['acted_at'] as String),
    synced: j['synced'] as bool? ?? false,
  );

  final String medicineId;

  /// Wall-clock time the dose was scheduled for (UTC container).
  final DateTime scheduledAt;
  final DoseStatus status;

  /// Real instant of the action.
  final DateTime actedAt;
  final bool synced;

  String get key => doseKey(medicineId, scheduledAt);

  DoseLog markSynced() => DoseLog(
    medicineId: medicineId,
    scheduledAt: scheduledAt,
    status: status,
    actedAt: actedAt,
    synced: true,
  );

  Map<String, dynamic> toJson() => {
    'medicine_id': medicineId,
    'scheduled_at': _wallIso(scheduledAt),
    'status': status.name,
    'acted_at': actedAt.toUtc().toIso8601String(),
    'synced': synced,
  };
}
