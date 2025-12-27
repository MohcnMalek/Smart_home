import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  Future<void> _init() async {
    if (_inited) return;
    _inited = true;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _init();
    await _tts.stop();
    await _tts.speak(t);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }
}
