import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum SnackbarType { success, error, warning, info }

class FeedbackSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
    VoidCallback? onUndo,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final config = _getConfig(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
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
              child: Text(
                message,
                style: AppTextStyles.leagueSpartan(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: duration,
        action: onUndo != null
            ? SnackBarAction(
                label: 'Desfazer',
                textColor: Colors.white,
                onPressed: onUndo,
              )
            : onAction != null && actionLabel != null
                ? SnackBarAction(
                    label: actionLabel,
                    textColor: Colors.white,
                    onPressed: onAction,
                  )
                : null,
      ),
    );
  }

  static void success(BuildContext context, String message, {VoidCallback? onUndo}) {
    show(context, message: message, type: SnackbarType.success, onUndo: onUndo);
  }

  static void error(BuildContext context, String message, {VoidCallback? onRetry}) {
    show(
      context,
      message: message,
      type: SnackbarType.error,
      onAction: onRetry,
      actionLabel: onRetry != null ? 'Tentar novamente' : null,
      duration: const Duration(seconds: 5),
    );
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, type: SnackbarType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: SnackbarType.info);
  }

  static _SnackbarConfig _getConfig(SnackbarType type) {
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

class _SnackbarConfig {
  final Color color;
  final IconData icon;

  _SnackbarConfig({required this.color, required this.icon});
}

