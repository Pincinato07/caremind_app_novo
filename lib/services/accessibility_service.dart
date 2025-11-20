import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

class AccessibilityService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setLanguage("pt-BR");
    await _tts.setSpeechRate(0.5); // Velocidade mais lenta para idosos
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _isInitialized = true;
  }

  /// Fala um texto usando Text-to-Speech
  static Future<void> speak(String text) async {
    await initialize();
    await _tts.speak(text);
  }

  /// Para a fala atual
  static Future<void> stop() async {
    await _tts.stop();
  }

  /// Feedback multissensorial: vibração longa + som de sucesso
  static Future<void> feedbackSucesso() async {
    // Vibração longa (500ms)
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 500);
    }

    // Som de sucesso (usando TTS com um som curto)
    await initialize();
    await _tts.speak("Sucesso!");
  }

  /// Vibração curta para feedback tátil
  static Future<void> vibrar({int duration = 200}) async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: duration);
    }
  }
}

