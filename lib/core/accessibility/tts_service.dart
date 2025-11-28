import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import '../injection/injection.dart';
import '../../services/settings_service.dart';

/// Serviço TTS centralizado e simplificado
/// Gerencia fala e vibração com base nas configurações do usuário
class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  SettingsService? _settingsService;

  /// Inicializa o serviço
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _settingsService = getIt<SettingsService>();
      _settingsService?.addListener(_updateSettings);
    } catch (e) {
      // SettingsService pode não estar disponível ainda
    }

    await _tts.setLanguage("pt-BR");
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _updateSettings();
    _isInitialized = true;
  }

  /// Atualiza configurações do TTS
  Future<void> _updateSettings() async {
    if (_settingsService != null) {
      await _tts.setSpeechRate(_settingsService!.accessibilityVoiceSpeed);
    } else {
      await _tts.setSpeechRate(0.5);
    }
  }

  /// Fala um texto se TTS estiver habilitado
  Future<void> speak(String text) async {
    await initialize();
    
    if (_settingsService != null && !_settingsService!.accessibilityTtsEnabled) {
      return;
    }

    await _tts.speak(text);
  }

  /// Para a fala atual
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Vibra se vibração estiver habilitada
  Future<void> vibrate({int duration = 200}) async {
    if (_settingsService != null && !_settingsService!.accessibilityVibrationEnabled) {
      return;
    }

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: duration);
    }
  }

  /// Feedback multissensorial: vibração + fala
  Future<void> feedback(String message, {bool vibrate = true}) async {
    await speak(message);
    if (vibrate) {
      await this.vibrate(duration: 300);
    }
  }

  /// Verifica se TTS está habilitado
  bool get isTtsEnabled {
    if (_settingsService == null) return true;
    return _settingsService!.accessibilityTtsEnabled;
  }

  /// Verifica se vibração está habilitada
  bool get isVibrationEnabled {
    if (_settingsService == null) return true;
    return _settingsService!.accessibilityVibrationEnabled;
  }
}
