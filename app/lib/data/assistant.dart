/// Assistant conversation models (backend: POST /assistant/chat).
library;

import '../schedule/schedule_models.dart';
import 'models.dart';

class ChatTurn {
  const ChatTurn(
    this.fromUser,
    this.text, {
    this.actions = const [],
    this.emergency,
  });

  final bool fromUser;
  final String text;
  final List<AssistantAction> actions;
  final String? emergency;

  Map<String, dynamic> toJson() => {
    'role': fromUser ? 'user' : 'assistant',
    'text': text,
  };
}

enum AssistantActionType { stopMedicine, changeMealTime }

/// A change suggested by the assistant; applied only after the user confirms.
class AssistantAction {
  const AssistantAction({
    required this.type,
    this.medicineId,
    this.meal,
    this.time,
  });

  factory AssistantAction.fromJson(Map<String, dynamic> j) => AssistantAction(
    type: j['type'] == 'stop_medicine'
        ? AssistantActionType.stopMedicine
        : AssistantActionType.changeMealTime,
    medicineId: j['medicine_id'] as String?,
    meal: j['meal'] as String?,
    time: j['time'] as String?,
  );

  final AssistantActionType type;
  final String? medicineId;
  final String? meal; // breakfast, lunch, evening, dinner, bedtime
  final String? time; // HH:MM
}

class AssistantReply {
  const AssistantReply(this.text, this.actions, this.emergency);

  factory AssistantReply.fromJson(Map<String, dynamic> j) =>
      AssistantReply(j['reply'] as String, [
        for (final a in j['actions'] as List)
          AssistantAction.fromJson(a as Map<String, dynamic>),
      ], j['emergency'] as String?);

  final String text;
  final List<AssistantAction> actions;
  final String? emergency;
}

String _clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// The user's own data sent with each question, so answers match the phone.
Map<String, dynamic> assistantContext({
  required List<Medicine> medicines,
  required ScheduleSettings settings,
  required DateTime now,
  String locale = 'bn',
  String? patientName,
}) => {
  'locale': locale,
  'now': now.toUtc().toIso8601String(),
  'patient_name': patientName,
  'settings': {
    'breakfast': _clock(settings.breakfast),
    'lunch': _clock(settings.lunch),
    'evening': _clock(settings.evening),
    'dinner': _clock(settings.dinner),
    'bedtime': _clock(settings.bedtime),
  },
  'medicines': [
    for (final m in medicines)
      {
        'id': m.id,
        'label': m.label,
        'dose_pattern': m.dosePattern,
        'interval_hours': m.intervalHours,
        'timing': timingJson[m.timing],
        'duration_days': m.durationDays,
        'weekdays': m.weekdays,
        'as_needed': m.asNeeded,
        'start': m.startAt.toUtc().toIso8601String(),
      },
  ],
};
