import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  Future<void> _init() async {
    if (_inited) return;
    _inited = true;

    // English voice
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.15); // slightly higher -> more "girl-like"
    await _tts.awaitSpeakCompletion(true);

    // Try to pick a female voice if available
    try {
      final voices = await _tts.getVoices; // List<dynamic>
      if (voices is List) {
        dynamic female;
        for (final v in voices) {
          final name = (v['name'] ?? '').toString().toLowerCase();
          final locale = (v['locale'] ?? '').toString().toLowerCase();

          // Heuristics: "female", or common female voice names
          final looksFemale = name.contains('female') ||
              name.contains('woman') ||
              name.contains('zira') ||
              name.contains('susan') ||
              name.contains('samantha') ||
              name.contains('karen') ||
              name.contains('tessa');

          final isEnglish = locale.startsWith('en');
          if (looksFemale && isEnglish) {
            female = v;
            break;
          }
        }

        if (female != null) {
          // flutter_tts expects a Map with name/locale on many devices
          await _tts.setVoice({
            "name": female['name'],
            "locale": female['locale'],
          });
        }
      }
    } catch (_) {
      // If device doesn't allow listing voices, we just keep default voice.
    }
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
