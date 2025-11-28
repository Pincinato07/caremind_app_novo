import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'settings_service.dart';
import '../core/injection/injection.dart';

/// Serviço de Acessibilidade integrado com configurações
/// Respeita preferências do usuário para TTS e vibração
class AccessibilityService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;
  static SettingsService? _settingsService;

  /// Inicializa o serviço e configura TTS
  static Future<void> initialize() async {
    if (_isInitialized) {
      await _updateTtsSettings();
      return;
    }

    try {
      _settingsService = getIt<SettingsService>();
      // Adicionar listener para mudanças em tempo real
      _settingsService?.addListener(_updateTtsSettings);
    } catch (e) {
      // SettingsService pode não estar disponível ainda
    }

    await _tts.setLanguage("pt-BR");
    await _updateTtsSettings();
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _isInitialized = true;
  }

  /// Atualiza configurações do TTS baseado nas preferências
  static Future<void> _updateTtsSettings() async {
    if (_settingsService != null) {
      final speed = _settingsService!.accessibilityVoiceSpeed;
      await _tts.setSpeechRate(speed);
    } else {
      // Valor padrão se settings não estiver disponível
      await _tts.setSpeechRate(0.5);
    }
  }

  /// Fala um texto usando Text-to-Speech (respeita configuração)
  static Future<void> speak(String text) async {
    await initialize();
    
    // Verificar se TTS está habilitado
    if (_settingsService != null && !_settingsService!.accessibilityTtsEnabled) {
      return; // TTS desabilitado, não fala
    }

    await _tts.speak(text);
  }

  /// Para a fala atual
  static Future<void> stop() async {
    await _tts.stop();
  }

  /// Feedback multissensorial: vibração longa + som de sucesso
  static Future<void> feedbackSucesso() async {
    // Vibração longa (500ms) - respeita configuração
    if (_settingsService == null || _settingsService!.accessibilityVibrationEnabled) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 500);
      }
    }

    // Som de sucesso (usando TTS com um som curto) - respeita configuração
    if (_settingsService == null || _settingsService!.accessibilityTtsEnabled) {
      await initialize();
      await _tts.speak("Sucesso!");
    }
  }

  /// Vibração curta para feedback tátil (respeita configuração)
  static Future<void> vibrar({int duration = 200}) async {
    // Verificar se vibração está habilitada
    if (_settingsService != null && !_settingsService!.accessibilityVibrationEnabled) {
      return; // Vibração desabilitada
    }

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: duration);
    }
  }

  /// Verifica se TTS está habilitado
  static bool get isTtsEnabled {
    if (_settingsService == null) return true; // Padrão: habilitado
    return _settingsService!.accessibilityTtsEnabled;
  }

  /// Verifica se vibração está habilitada
  static bool get isVibrationEnabled {
    if (_settingsService == null) return true; // Padrão: habilitado
    return _settingsService!.accessibilityVibrationEnabled;
  }

  /// Atualiza referência ao SettingsService (chamado quando settings mudam)
  static void updateSettingsService() {
    try {
      _settingsService = getIt<SettingsService>();
      _updateTtsSettings();
    } catch (e) {
      // Ignora se não estiver disponível
    }
  }
}

