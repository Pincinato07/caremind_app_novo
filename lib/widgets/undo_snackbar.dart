import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Snackbar com contador de tempo para desfazer ação
class UndoSnackbar extends StatefulWidget {
  final String message;
  final VoidCallback onUndo;
  final Duration duration;
  final SnackbarType type;

  const UndoSnackbar({
    super.key,
    required this.message,
    required this.onUndo,
    this.duration = const Duration(seconds: 15),
    this.type = SnackbarType.success,
  });

  @override
  State<UndoSnackbar> createState() => _UndoSnackbarState();

  /// Mostra um snackbar com undo e contador
  static void show(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 15),
    SnackbarType type = SnackbarType.success,
  }) {
    try {
      if (!context.mounted) {
        debugPrint('⚠️ UndoSnackbar: Context não está montado');
        return;
      }
      
      if (message.isEmpty) {
        debugPrint('⚠️ UndoSnackbar: Mensagem vazia');
        return;
      }
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UndoSnackbar(
            message: message,
            onUndo: onUndo,
            duration: duration,
            type: type,
          ),
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: duration,
          elevation: 0,
        ),
      );
    } catch (e) {
      debugPrint('❌ UndoSnackbar: Erro ao mostrar snackbar - $e');
    }
  }
}

class _UndoSnackbarState extends State<UndoSnackbar> {
  Timer? _timer;
  int _remainingSeconds = 15;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.duration.inSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    try {
      _timer?.cancel(); // Cancelar timer anterior se existir
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        try {
          setState(() {
            if (_remainingSeconds > 0) {
              _remainingSeconds--;
            }
          });
          if (_remainingSeconds <= 0) {
            timer.cancel();
          }
        } catch (e) {
          debugPrint('❌ UndoSnackbar: Erro ao atualizar contador - $e');
          timer.cancel();
        }
      });
    } catch (e) {
      debugPrint('❌ UndoSnackbar: Erro ao iniciar contador - $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleUndo() {
    try {
      _timer?.cancel();
      widget.onUndo();
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      debugPrint('❌ UndoSnackbar: Erro ao executar undo - $e');
      // Tentar fechar o snackbar mesmo em caso de erro
      try {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      } catch (_) {
        // Ignorar erro ao fechar
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(widget.type);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              config.icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.message,
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (_remainingSeconds > 0)
                  Text(
                    'Desfazer em $_remainingSeconds segundos',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _handleUndo,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'DESFAZER',
              style: AppTextStyles.leagueSpartan(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _SnackbarConfig _getConfig(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return _SnackbarConfig(
          color: const Color(0xFF2E7D32),
          icon: Icons.check_circle_rounded,
        );
      case SnackbarType.error:
        return _SnackbarConfig(
          color: const Color(0xFFC62828),
          icon: Icons.error_rounded,
        );
      case SnackbarType.warning:
        return _SnackbarConfig(
          color: const Color(0xFFF57C00),
          icon: Icons.warning_rounded,
        );
      case SnackbarType.info:
        return _SnackbarConfig(
          color: AppColors.primary,
          icon: Icons.info_rounded,
        );
    }
  }
}

enum SnackbarType { success, error, warning, info }

class _SnackbarConfig {
  final Color color;
  final IconData icon;

  _SnackbarConfig({required this.color, required this.icon});
}

