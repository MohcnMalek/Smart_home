import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class VoiceService {
  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    try {
      final synth = js.context['speechSynthesis'];
      final ctor = js.context['SpeechSynthesisUtterance'];

      if (synth == null || ctor == null) {
        debugPrint('Web TTS not available in this browser.');
        return;
      }

      // stop any current speech
      synth.callMethod('cancel');

      // create utterance
      final utt = js.JsObject(ctor, [t]);

      // configure voice
      utt['lang'] = 'en-US';
      utt['rate'] = 0.95; // 0.1 .. 10 (browser dependent)
      utt['pitch'] = 1.0; // 0 .. 2

      // speak
      synth.callMethod('speak', [utt]);
    } catch (e) {
      debugPrint('Web TTS error: $e');
    }
  }

  Future<void> stop() async {
    try {
      final synth = js.context['speechSynthesis'];
      synth?.callMethod('cancel');
    } catch (e) {
      debugPrint('Web TTS stop error: $e');
    }
  }

  void dispose() {
    // ignore: discarded_futures
    stop();
  }
}
