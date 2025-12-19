import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class ErrorWidgetWithRetry extends StatefulWidget {
  final String message;
  final VoidCallback onRetry;
  final String? details;
  final IconData? icon;
  final bool autoRetry;
  final int maxAutoRetries;

  const ErrorWidgetWithRetry({
    super.key,
    required this.message,
    required this.onRetry,
    this.details,
    this.icon,
    this.autoRetry = true,
    this.maxAutoRetries = 3,
  });

  @override
  State<ErrorWidgetWithRetry> createState() => _ErrorWidgetWithRetryState();
}

class _ErrorWidgetWithRetryState extends State<ErrorWidgetWithRetry> {
  int _retryCount = 0;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoRetry) {
      _scheduleAutoRetry();
    }
  }

  void _scheduleAutoRetry() {
    if (_retryCount < widget.maxAutoRetries && mounted) {
      Future.delayed(Duration(seconds: 3 + (_retryCount * 2)), () {
        if (mounted && _retryCount < widget.maxAutoRetries) {
          _handleRetry();
        }
      });
    }
  }

  Future<void> _handleRetry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
      _retryCount++;
    });

    try {
      widget.onRetry();
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  String _getFriendlyMessage(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('conexão') ||
        lowerMessage.contains('internet') ||
        lowerMessage.contains('socketexception')) {
      return 'Sem conexão com a internet';
    }

    if (lowerMessage.contains('timeout') || lowerMessage.contains('tempo')) {
      return 'A conexão demorou muito. Tente novamente';
    }

    if (lowerMessage.contains('401') || lowerMessage.contains('unauthorized')) {
      return 'Sua sessão expirou. Faça login novamente';
    }

    if (lowerMessage.contains('403') || lowerMessage.contains('forbidden')) {
      return 'Você não tem permissão para acessar isso';
    }

    if (lowerMessage.contains('404') || lowerMessage.contains('not found')) {
      return 'Conteúdo não encontrado';
    }

    if (lowerMessage.contains('500') || lowerMessage.contains('server')) {
      return 'Nossos servidores estão com problemas. Tente em alguns minutos';
    }

    return 'Algo deu errado. Tente novamente';
  }

  IconData _getErrorIcon(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('conexão') ||
        lowerMessage.contains('internet')) {
      return Icons.wifi_off_rounded;
    }

    if (lowerMessage.contains('timeout')) {
      return Icons.hourglass_empty_rounded;
    }

    if (lowerMessage.contains('401') || lowerMessage.contains('403')) {
      return Icons.lock_outline_rounded;
    }

    return Icons.error_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final friendlyMessage = _getFriendlyMessage(widget.message);
    final icon = widget.icon ?? _getErrorIcon(widget.message);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: AppColors.error.withValues(alpha: 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            friendlyMessage,
            style: AppTextStyles.leagueSpartan(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.autoRetry && _retryCount < widget.maxAutoRetries) ...[
            const SizedBox(height: 8),
            Text(
              'Tentando novamente automaticamente... (${_retryCount}/${widget.maxAutoRetries})',
              style: AppTextStyles.leagueSpartan(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRetrying ? null : _handleRetry,
              icon: _isRetrying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(_isRetrying ? 'Tentando...' : 'Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InlineErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const InlineErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  String _getFriendlyMessage(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('network') || lowerMessage.contains('conexão')) {
      return 'Sem conexão';
    }
    if (lowerMessage.contains('timeout')) {
      return 'Tempo esgotado';
    }
    return 'Erro ao carregar';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: Colors.white.withValues(alpha: 0.8),
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          _getFriendlyMessage(message),
          style: AppTextStyles.leagueSpartan(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Tentar novamente',
              style: AppTextStyles.leagueSpartan(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ).copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
