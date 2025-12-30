import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../errors/app_exception.dart';

/// Serviço centralizado para feedback ao usuário (SnackBars, Dialogs, etc)
///
/// SUBSTITUI: 105 SnackBars duplicados em 32 telas
///
/// @example
/// ```dart
/// // Sucesso
/// FeedbackService.showSuccess(context, 'Operação concluída!');
///
/// // Erro
/// FeedbackService.showError(context, exception);
///
/// // Rate limit específico
/// FeedbackService.showRateLimit(context, rateLimitException);
/// ```
class FeedbackService {
  FeedbackService._(); // Private constructor para impedir instanciação

  /// Duração padrão dos SnackBars
  static const Duration _defaultDuration = Duration(seconds: 4);
  static const Duration _longDuration = Duration(seconds: 6);
  static const Duration _shortDuration = Duration(seconds: 2);

  /// Mostra mensagem de sucesso (verde)
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? _defaultDuration,
        action: action,
      ),
    );
  }

  /// Mostra mensagem informativa (azul)
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? _defaultDuration,
        action: action,
      ),
    );
  }

  /// Mostra mensagem de aviso (laranja)
  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? _longDuration,
        action: action,
      ),
    );
  }

  /// Mostra mensagem de erro genérica (vermelho)
  static void showErrorMessage(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? _longDuration,
        action: action,
      ),
    );
  }

  /// Mostra erro baseado em AppException (com lógica específica por tipo)
  static void showError(
    BuildContext context,
    AppException exception, {
    VoidCallback? onRetry,
  }) {
    // Rate Limit Exception - usar dialog específico
    if (exception is RateLimitException) {
      showRateLimit(context, exception);
      return;
    }

    // ClaimProfile Exception - mostrar mensagem formatada
    if (exception is ClaimProfileException) {
      showErrorMessage(
        context,
        exception.formattedMessage,
        duration: _longDuration,
      );
      return;
    }

    // Network Exception - adicionar botão de retry
    if (exception is NetworkException && onRetry != null) {
      showErrorMessage(
        context,
        exception.message,
        duration: _longDuration,
        action: SnackBarAction(
          label: 'Tentar Novamente',
          textColor: Colors.white,
          onPressed: onRetry,
        ),
      );
      return;
    }

    // Authentication Exception - sugerir relogin
    if (exception is AuthenticationException) {
      showErrorMessage(
        context,
        exception.message,
        duration: _longDuration,
      );
      return;
    }

    // Erro genérico
    showErrorMessage(context, exception.message);
  }

  /// Mostra dialog de rate limit (bloqueio por excesso de tentativas)
  ///
  /// Exibe modal com informações de bloqueio, countdown e botão de suporte
  static void showRateLimit(
    BuildContext context,
    RateLimitException exception,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Acesso Bloqueado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exception.formattedMessage),
            if (exception.blockedUntil != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tente novamente às ${exception.blockedUntil!.hour.toString().padLeft(2, '0')}:${exception.blockedUntil!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  /// Mostra loading SnackBar (útil para operações longas)
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoading(
    BuildContext context,
    String message,
  ) {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(
            days: 1), // Muito longo, deve ser fechado manualmente
      ),
    );
  }

  /// Fecha o SnackBar atual
  static void hideSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Remove todos os SnackBars da fila
  static void clearSnackBars(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Abre uma URL no navegador externo
  static Future<void> launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Não foi possível abrir a URL: $url');
    }
  }

  /// Mostra dialog de confirmação
  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Mostra dialog de erro com detalhes
  static Future<void> showErrorDialog(
    BuildContext context,
    AppException exception, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title ?? 'Erro')),
          ],
        ),
        content: Text(exception.message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Tentar Novamente'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Mostra mensagem rápida de progresso (2 segundos)
  static void showQuick(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: _shortDuration,
      ),
    );
  }
}
