import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Recorded voice lines (assets/voice/<file>.ogg). The alarm sound itself is a notification sound
/// (android/app/src/main/res/raw/alarm_ring.ogg), so it also rings with the app closed.
enum VoiceClip {
  alarmOpen('alarm_open'), // the alarm screen opened
  reminderAgain('reminder_again'), // a snoozed alarm rang again
  testAlarm('test_alarm'), // the test alarm from Reminder settings
  taken('taken'),
  snoozed('snoozed'),
  skipped('skipped');

  const VoiceClip(this.file);
  final String file;

  String get asset => 'assets/voice/$file.ogg';
}

/// Plays recorded voice lines. A missing recording plays nothing (returns false), so clips can be
/// added one at a time.
abstract interface class VoicePlayer {
  /// Plays [clip] to the end; false when there is no recording for it.
  Future<bool> play(VoiceClip clip);

  Future<void> stop();
}

class AssetVoicePlayer implements VoicePlayer {
  AssetVoicePlayer([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final Map<VoiceClip, bool> _available = {};
  bool _configured = false;

  Future<bool> _exists(VoiceClip clip) async =>
      _available[clip] ??= await rootBundle
          .load(clip.asset)
          .then((_) => true, onError: (Object _) => false);

  Future<void> _configure() async {
    if (_configured) return;
    // Play on the alarm volume, like the alarm sound, and take audio focus from music
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.speech,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
    await _player.setReleaseMode(ReleaseMode.stop);
    _configured = true;
  }

  @override
  Future<bool> play(VoiceClip clip) async {
    if (!await _exists(clip)) return false;
    try {
      await _configure();
      await _player.stop();
      final done = _player.onPlayerComplete.first;
      // AssetSource paths are relative to the assets/ folder
      await _player.play(AssetSource('voice/${clip.file}.ogg'));
      await done.timeout(const Duration(seconds: 30));
      return true;
    } on Object {
      return false; // a voice line must never block answering the alarm
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object {
      // already stopped or not started
    }
  }
}

/// For tests: records what would have been played.
class RecordingVoicePlayer implements VoicePlayer {
  RecordingVoicePlayer({this.available = const {}});

  final Set<VoiceClip> available;
  final List<VoiceClip> played = [];
  int stops = 0;

  @override
  Future<bool> play(VoiceClip clip) async {
    if (!available.contains(clip)) return false;
    played.add(clip);
    return true;
  }

  @override
  Future<void> stop() async => stops++;
}
