import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();

  bool _ready = false;

  Future<bool> init() async {
    _ready = await _stt.initialize();
    return _ready;
  }

  bool get isAvailable => _ready;

  bool get isListening => _stt.isListening;

  Future<void> start({
    required void Function(String finalText) onFinalResult,
    void Function(String error)? onError,
  }) async {
    if (!_ready) {
      final ok = await init();
      if (!ok) {
        onError?.call("Speech-to-text indisponible sur cet appareil.");
        return;
      }
    }

    await _stt.listen(
      onResult: (res) {
        if (res.finalResult) {
          final text = res.recognizedWords.trim();
          if (text.isNotEmpty) onFinalResult(text);
        }
      },
      partialResults: false,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  Future<void> stop() async {
    await _stt.stop();
  }
}
