import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço centralizado para gerenciar todas as configurações do app
/// Usa SharedPreferences para persistência local
class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Chaves para SharedPreferences
  static const String _keyNotificationsMedicamentos =
      'notifications_medicamentos';
  static const String _keyNotificationsCompromissos =
      'notifications_compromissos';
  static const String _keyAccessibilityTtsEnabled = 'accessibility_tts_enabled';
  static const String _keyAccessibilityVibrationEnabled =
      'accessibility_vibration_enabled';
  static const String _keyAccessibilityFontScale = 'accessibility_font_scale';
  static const String _keyAccessibilityHighContrast =
      'accessibility_high_contrast';
  static const String _keyAccessibilityAutoRead = 'accessibility_auto_read';
  static const String _keyAccessibilityVoiceSpeed = 'accessibility_voice_speed';
  static const String _keyWavesEnabled = 'waves_enabled';

  // Valores padrão
  static const bool _defaultNotificationsMedicamentos = true;
  static const bool _defaultNotificationsCompromissos = true;
  static const bool _defaultAccessibilityTtsEnabled = true;
  static const bool _defaultAccessibilityVibrationEnabled = true;
  static const double _defaultAccessibilityFontScale = 1.0;
  static const bool _defaultAccessibilityHighContrast = false;
  static const bool _defaultAccessibilityAutoRead = false;
  static const double _defaultAccessibilityVoiceSpeed = 0.5;
  static const bool _defaultWavesEnabled = true;

  // Valores em memória (cache)
  bool? _notificationsMedicamentos;
  bool? _notificationsCompromissos;
  bool? _accessibilityTtsEnabled;
  bool? _accessibilityVibrationEnabled;
  double? _accessibilityFontScale;
  bool? _accessibilityHighContrast;
  bool? _accessibilityAutoRead;
  double? _accessibilityVoiceSpeed;
  bool? _wavesEnabled;

  /// Inicializa o serviço carregando preferências
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadAllSettings();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao inicializar SettingsService: $e');
      _isInitialized = true; // Continua mesmo com erro
    }
  }

  /// Carrega todas as configurações do SharedPreferences
  Future<void> _loadAllSettings() async {
    if (_prefs == null) return;

    _notificationsMedicamentos =
        _prefs!.getBool(_keyNotificationsMedicamentos) ??
            _defaultNotificationsMedicamentos;
    _notificationsCompromissos =
        _prefs!.getBool(_keyNotificationsCompromissos) ??
            _defaultNotificationsCompromissos;
    _accessibilityTtsEnabled = _prefs!.getBool(_keyAccessibilityTtsEnabled) ??
        _defaultAccessibilityTtsEnabled;
    _accessibilityVibrationEnabled =
        _prefs!.getBool(_keyAccessibilityVibrationEnabled) ??
            _defaultAccessibilityVibrationEnabled;
    _accessibilityFontScale = _prefs!.getDouble(_keyAccessibilityFontScale) ??
        _defaultAccessibilityFontScale;
    _accessibilityHighContrast =
        _prefs!.getBool(_keyAccessibilityHighContrast) ??
            _defaultAccessibilityHighContrast;
    _accessibilityAutoRead = _prefs!.getBool(_keyAccessibilityAutoRead) ??
        _defaultAccessibilityAutoRead;
    _accessibilityVoiceSpeed = _prefs!.getDouble(_keyAccessibilityVoiceSpeed) ??
        _defaultAccessibilityVoiceSpeed;
    _wavesEnabled = _prefs!.getBool(_keyWavesEnabled) ?? _defaultWavesEnabled;
  }

  // Getters
  bool get notificationsMedicamentos =>
      _notificationsMedicamentos ?? _defaultNotificationsMedicamentos;
  bool get notificationsCompromissos =>
      _notificationsCompromissos ?? _defaultNotificationsCompromissos;
  bool get accessibilityTtsEnabled =>
      _accessibilityTtsEnabled ?? _defaultAccessibilityTtsEnabled;
  bool get accessibilityVibrationEnabled =>
      _accessibilityVibrationEnabled ?? _defaultAccessibilityVibrationEnabled;
  double get accessibilityFontScale =>
      _accessibilityFontScale ?? _defaultAccessibilityFontScale;
  bool get accessibilityHighContrast =>
      _accessibilityHighContrast ?? _defaultAccessibilityHighContrast;
  bool get accessibilityAutoRead =>
      _accessibilityAutoRead ?? _defaultAccessibilityAutoRead;
  double get accessibilityVoiceSpeed =>
      _accessibilityVoiceSpeed ?? _defaultAccessibilityVoiceSpeed;
  bool get wavesEnabled => _wavesEnabled ?? _defaultWavesEnabled;

  // Setters com persistência
  Future<bool> setNotificationsMedicamentos(bool value) async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return false;

    final success = await _prefs!.setBool(_keyNotificationsMedicamentos, value);
    if (success) {
      _notificationsMedicamentos = value;
      notifyListeners();
    }
    return success;
  }

  Future<bool> setNotificationsCompromissos(bool value) async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return false;

    final success = await _prefs!.setBool(_keyNotificationsCompromissos, value);
    if (success) {
      _notificationsCompromissos = value;
      notifyListeners();
    }
    return success;
  }

  Future<bool> setAccessibilityTtsEnabled(bool value) async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return false;

    final success = await _prefs!.setBool(_keyAccessibilityTtsEnabled, value);
    if (success) {
      _accessibilityTtsEnabled = value;
      notifyListeners();
    }
    return success;
  }

  Future<bool> setAccessibilityVibrationEnabled(bool value) async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return false;

    final success =
        await _prefs!.setBool(_keyAccessibilityVibrationEnabled, value);
    if (success) {
      _accessibilityVibrationEnabled = value;
      notifyListeners();
    }
    return success;
  }

  Future<bool> setAccessibilityFontScale(double value) async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return false;

    // Validar range: 0.8 - 2.0
    final clampedValue = value.clamp(0.8, 2.0);
    final success =
        await _prefs!.setDouble(_keyAccessibilityFontScale, clampedValue);
    if (success) {
      _accessibilityFontScale = clampedValue;
      notifyListeners();
    }
    return success;
  }

  Future<bool> setAccessibilityHighContrast(bool value) async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return false;

    final success = await _prefs!.setBool(_keyAccessibilityHighContrast, value);
    if (success) {
      _accessibilityHighContrast = value;
      notifyListeners();
    }
    return success;
  }

  Future<bool> setAccessibilityAutoRead(bool value) async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return false;

    final success = await _prefs!.setBool(_keyAccessibilityAutoRead, value);
    if (success) {
      _accessibilityAutoRead = value;
      notifyListeners();
    }
    return success;
  }

  Future<bool> setAccessibilityVoiceSpeed(double value) async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return false;

    // Validar range: 0.3 - 1.0
    final clampedValue = value.clamp(0.3, 1.0);
    final success =
        await _prefs!.setDouble(_keyAccessibilityVoiceSpeed, clampedValue);
    if (success) {
      _accessibilityVoiceSpeed = clampedValue;
      notifyListeners();
    }
    return success;
  }

  Future<bool> setWavesEnabled(bool value) async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return false;

    final success = await _prefs!.setBool(_keyWavesEnabled, value);
    if (success) {
      _wavesEnabled = value;
      notifyListeners();
    }
    return success;
  }

  /// Reseta todas as configurações para os valores padrão
  Future<void> resetToDefaults() async {
    if (_prefs == null) await initialize();
    if (_prefs == null) return;

    await setNotificationsMedicamentos(_defaultNotificationsMedicamentos);
    await setNotificationsCompromissos(_defaultNotificationsCompromissos);
    await setAccessibilityTtsEnabled(_defaultAccessibilityTtsEnabled);
    await setAccessibilityVibrationEnabled(
        _defaultAccessibilityVibrationEnabled);
    await setAccessibilityFontScale(_defaultAccessibilityFontScale);
    await setAccessibilityHighContrast(_defaultAccessibilityHighContrast);
    await setAccessibilityAutoRead(_defaultAccessibilityAutoRead);
    await setAccessibilityVoiceSpeed(_defaultAccessibilityVoiceSpeed);
    await setWavesEnabled(_defaultWavesEnabled);
  }
}
