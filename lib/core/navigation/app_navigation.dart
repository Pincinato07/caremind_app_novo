import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Helper centralizado para navegação com transições suaves e consistentes
class AppNavigation {
  // Transição padrão suave (fade + slide)
  static PageRoute<T> smoothRoute<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOutCubic,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Fade
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        // Slide (sutil)
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.02),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
    );
  }

  // Transição modal (de baixo para cima)
  static PageRoute<T> modalRoute<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 250),
    bool barrierDismissible = true,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      barrierDismissible: barrierDismissible,
      opaque: false,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  // Navegação com feedback háptico
  static Future<T?> pushWithHaptic<T extends Object?>(
    BuildContext context,
    Widget page, {
    bool useModal = false,
  }) async {
    // Feedback háptico leve
    // HapticFeedback.lightImpact(); // Descomente se tiver o pacote
    return Navigator.of(context).push<T>(
      useModal ? modalRoute(page) : smoothRoute(page),
    );
  }

  // Navegação com replace
  static Future<T?> pushReplacementWithHaptic<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget page, {
    TO? result,
  }) async {
    // HapticFeedback.lightImpact();
    return Navigator.of(context).pushReplacement<T, TO>(
      smoothRoute(page),
      result: result,
    );
  }

  // Navegação com replace até
  static Future<T?> pushAndRemoveUntilWithHaptic<T extends Object?>(
    BuildContext context,
    Widget page,
  ) async {
    // HapticFeedback.lightImpact();
    return Navigator.of(context).pushAndRemoveUntil<T>(
      smoothRoute(page),
      (route) => false,
    );
  }

  // Dialog padronizado
  static Future<T?> showAppDialog<T>({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: GoogleFonts.leagueSpartan(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.leagueSpartan(
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          if (cancelText != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onCancel?.call();
              },
              child: Text(
                cancelText,
                style: GoogleFonts.leagueSpartan(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: isDestructive ? Colors.red : const Color(0xFF0400BA),
            ),
            child: Text(
              confirmText ?? 'OK',
              style: GoogleFonts.leagueSpartan(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bottom sheet padronizado
  static Future<T?> showAppBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

