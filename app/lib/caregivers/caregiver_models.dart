import '../alarms/dose_log.dart';
import '../data/models.dart';
import '../schedule/schedule_models.dart';

enum CaregiverPermission { view, edit }

class CaregiverLink {
  const CaregiverLink({
    required this.id,
    required this.patientId,
    required this.caregiverId,
    required this.permission,
    this.patientName,
    this.caregiverName,
  });

  final String id;
  final String patientId;
  final String caregiverId;
  final CaregiverPermission permission;
  final String? patientName;
  final String? caregiverName;
}

/// Everything a caregiver's dashboard needs about one patient.
class PatientSnapshot {
  const PatientSnapshot({
    required this.patientId,
    required this.name,
    required this.settings,
    required this.medicines,
    required this.logs,
  });

  final String patientId;
  final String? name;
  final ScheduleSettings settings;
  final List<Medicine> medicines;
  final List<DoseLog> logs;
}

class CaregiverException implements Exception {
  const CaregiverException(this.code);

  final String code; // invite_invalid, invite_own, network_error

  @override
  String toString() => 'CaregiverException($code)';
}
