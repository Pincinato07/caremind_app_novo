import 'package:flutter/foundation.dart';

/// Logger centralizado para o aplicativo Caremind.
/// Exibe logs apenas em modo debug.
class AppLogger {
  static void info(dynamic message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  static void warn(dynamic message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) debugPrint('Error: $error');
      if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
    }
    // TODO: Adicionar integração com Sentry ou outro serviço de monitoramento aqui se necessário para produção
  }

  static void debug(dynamic message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }
}
