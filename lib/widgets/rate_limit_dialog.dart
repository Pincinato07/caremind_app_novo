import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/errors/app_exception.dart';
import '../core/config/app_config.dart';

/// Widget reutilizável para mostrar bloqueio por rate limiting
///
/// SUBSTITUI: Modal fake inline com Stack usado em claim_profile_screen
///
/// @example
/// ```dart
/// // Mostrar dialog
/// RateLimitDialog.show(context, exception);
///
/// // Ou usando widget diretamente
/// showDialog(
///   context: context,
///   builder: (_) => RateLimitDialog(exception: exception),
/// );
/// ```
class RateLimitDialog extends StatelessWidget {
  final RateLimitException exception;
  final VoidCallback? onClose;

  const RateLimitDialog({
    super.key,
    required this.exception,
    this.onClose,
  });

  /// Helper estático para mostrar o dialog
  static Future<void> show(
    BuildContext context,
    RateLimitException exception, {
    VoidCallback? onClose,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RateLimitDialog(
        exception: exception,
        onClose: onClose,
      ),
    );
  }

  Future<void> _abrirWhatsAppSuporte(BuildContext context) async {
    final numero = AppConfig.SUPPORT_WHATSAPP_NUMBER;
    const mensagem =
        'Olá, preciso de ajuda com o código de vinculação do CareMind.';
    final url = Uri.parse(
        'https://wa.me/$numero?text=${Uri.encodeComponent(mensagem)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir o WhatsApp'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao abrir o WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _fechar(BuildContext context) {
    Navigator.of(context).pop();
    onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícone
          Icon(
            Icons.lock_clock,
            size: 64,
            color: Colors.red.shade700,
          ),
          const SizedBox(height: 16),

          // Título
          const Text(
            'Acesso Bloqueado',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Mensagem principal
          Text(
            exception.formattedMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),

          // Informação de quando pode tentar novamente
          if (exception.blockedUntil != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tente novamente às ${exception.blockedUntil!.hour.toString().padLeft(2, '0')}:${exception.blockedUntil!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Seção de ajuda
          const Text(
            'Precisa de ajuda?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Botão WhatsApp
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _abrirWhatsAppSuporte(context),
              icon: const Icon(Icons.chat),
              label: const Text('Abrir WhatsApp do Suporte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Botão Fechar
          TextButton(
            onPressed: () => _fechar(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

/// Widget simplificado apenas para mostrar informação de rate limit (sem modal)
class RateLimitWarning extends StatelessWidget {
  final RateLimitException exception;

  const RateLimitWarning({
    super.key,
    required this.exception,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lock_clock, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Acesso Temporariamente Bloqueado',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exception.formattedMessage,
            style: TextStyle(
              color: Colors.red.shade900,
              fontSize: 14,
            ),
          ),
          if (exception.blockedUntil != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tente novamente às ${exception.blockedUntil!.hour.toString().padLeft(2, '0')}:${exception.blockedUntil!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
