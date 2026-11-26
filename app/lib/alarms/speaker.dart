import 'package:flutter_tts/flutter_tts.dart';

/// Reads alarm text aloud.
abstract interface class Speaker {
  Future<void> speak(String text);

  Future<void> stop();
}

class TtsSpeaker implements Speaker {
  TtsSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    for (final lang in const ['bn-BD', 'bn-IN', 'bn']) {
      if (await _tts.isLanguageAvailable(lang) == true) {
        await _tts.setLanguage(lang);
        break;
      }
    }
    await _tts.setSpeechRate(0.45); // slower, for older listeners
    _configured = true;
  }

  @override
  Future<void> speak(String text) async {
    await _configure();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}

class SilentSpeaker implements Speaker {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}
