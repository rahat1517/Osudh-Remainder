import 'package:speech_to_text/speech_to_text.dart';

/// Turns speech into text (Bangla by default).
abstract interface class VoiceInput {
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    String localeId,
  });

  Future<void> stop();
}

class SpeechVoiceInput implements VoiceInput {
  final _speech = SpeechToText();
  bool _ready = false;

  @override
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    String localeId = 'bn_BD',
  }) async {
    _ready = _ready || await _speech.initialize();
    if (!_ready) return false;
    await _speech.listen(
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
      ),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}

class NoVoiceInput implements VoiceInput {
  @override
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    String localeId = 'bn_BD',
  }) async => false;

  @override
  Future<void> stop() async {}
}
