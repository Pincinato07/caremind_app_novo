import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/accessibility_service.dart';
import '../../core/injection/injection.dart';

/// Helpers para facilitar adição de semântica e acessibilidade
class AccessibilityHelper {
  /// Adiciona semântica a um botão
  static Widget semanticButton({
    required Widget child,
    required String label,
    String? hint,
    bool? enabled,
  }) {
    return Semantics(
      label: label,
      hint: hint ?? 'Toque para executar ação',
      button: true,
      enabled: enabled ?? true,
      child: child,
    );
  }

  /// Adiciona semântica a um campo de texto
  static Widget semanticTextField({
    required Widget child,
    required String label,
    String? hint,
    String? value,
  }) {
    return Semantics(
      label: label,
      hint: hint ?? 'Digite o texto',
      textField: true,
      value: value,
      child: child,
    );
  }

  /// Adiciona semântica a um item de lista
  static Widget semanticListItem({
    required Widget child,
    required String label,
    String? hint,
    bool? selected,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      selected: selected ?? false,
      child: child,
    );
  }

  /// Adiciona semântica a um cabeçalho/título
  static Widget semanticHeader({
    required Widget child,
    required String label,
    int level = 1,
  }) {
    return Semantics(
      label: label,
      header: true,
      child: child,
    );
  }

  /// Adiciona feedback háptico e TTS quando configurado
  static Future<void> provideFeedback({
    String? ttsMessage,
    bool vibrate = false,
    int vibrationDuration = 200,
  }) async {
    // Vibração se habilitada
    if (vibrate && AccessibilityService.isVibrationEnabled) {
      await AccessibilityService.vibrar(duration: vibrationDuration);
    }

    // TTS se habilitado
    if (ttsMessage != null && AccessibilityService.isTtsEnabled) {
      await AccessibilityService.speak(ttsMessage);
    }
  }

  /// Verifica se leitura automática está habilitada
  static bool shouldAutoRead() {
    try {
      final settings = getIt<SettingsService>();
      return settings.accessibilityAutoRead;
    } catch (e) {
      return false;
    }
  }

  /// Lê um texto automaticamente se a configuração estiver habilitada
  static Future<void> autoReadIfEnabled(String text) async {
    if (shouldAutoRead()) {
      await AccessibilityService.speak(text);
    }
  }
}

