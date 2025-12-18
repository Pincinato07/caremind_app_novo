import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/notificacao_app.dart';

/// Widget para exibir notificações in-app (toast/snackbar estilizado)
/// 
/// Usado para mostrar notificações quando o app está em foreground
/// e uma push notification chega via FCM.
class InAppNotification extends StatefulWidget {
  final String titulo;
  final String mensagem;
  final String tipo; // 'info', 'warning', 'error', 'success', 'medicamento', 'rotina', 'compromisso'
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Duration duration;

  const InAppNotification({
    super.key,
    required this.titulo,
    required this.mensagem,
    this.tipo = 'info',
    this.onTap,
    this.onDismiss,
    this.duration = const Duration(seconds: 4),
  });

  /// Mostrar uma notificação in-app
  static void show(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String tipo = 'info',
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: InAppNotification(
            titulo: titulo,
            mensagem: mensagem,
            tipo: tipo,
            onTap: () {
              overlayEntry.remove();
              onTap?.call();
            },
            onDismiss: () {
              overlayEntry.remove();
            },
            duration: duration,
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  /// Mostrar notificação a partir de um objeto NotificacaoApp
  static void showFromNotificacao(
    BuildContext context,
    NotificacaoApp notificacao, {
    VoidCallback? onTap,
  }) {
    show(
      context,
      titulo: notificacao.titulo,
      mensagem: notificacao.mensagem,
      tipo: notificacao.tipo,
      onTap: onTap,
    );
  }

  @override
  State<InAppNotification> createState() => _InAppNotificationState();
}

class _InAppNotificationState extends State<InAppNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Auto-dismiss após duração
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss?.call();
  }

  Color _getBackgroundColor() {
    switch (widget.tipo) {
      case 'error':
        return const Color(0xFFDC2626);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'success':
        return const Color(0xFF10B981);
      case 'medicamento':
        return const Color(0xFF8B5CF6);
      case 'rotina':
        return const Color(0xFF3B82F6);
      case 'compromisso':
        return const Color(0xFF06B6D4);
      default:
        return AppColors.primary;
    }
  }

  IconData _getIcon() {
    switch (widget.tipo) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_outline;
      case 'medicamento':
        return Icons.medication_liquid;
      case 'rotina':
        return Icons.schedule_rounded;
      case 'compromisso':
        return Icons.calendar_today;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 100) {
              _dismiss();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Ícone
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIcon(),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Conteúdo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.titulo,
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.mensagem,
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botão de fechar
                GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget badge para mostrar contagem de notificações não lidas
class NotificationBadge extends StatelessWidget {
  final int count;
  final Widget child;
  final Color? badgeColor;
  final Color? textColor;

  const NotificationBadge({
    super.key,
    required this.count,
    required this.child,
    this.badgeColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor ?? Colors.red,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: (badgeColor ?? Colors.red).withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Center(
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: AppTextStyles.leagueSpartan(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


