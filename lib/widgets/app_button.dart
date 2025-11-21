import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Botão primário padronizado seguindo o design das telas de auth
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? height;
  final double? width;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = const Color(0xFF0400BA);
    return SizedBox(
      height: height ?? 44,
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF020054);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return const Color(0xFF0600E0);
            }
            return baseColor;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(
            Colors.white.withValues(alpha: 0.06),
          ),
          elevation: WidgetStateProperty.all(6),
          shadowColor: WidgetStateProperty.all(
            baseColor.withValues(alpha: 0.2),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.leagueSpartan(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Botão outline padronizado
class AppOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? height;
  final double? width;

  const AppOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? 44,
      width: width,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: onPressed == null
                ? Colors.grey[400]!
                : Colors.white.withValues(alpha: 0.8),
            width: 1.5,
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.leagueSpartan(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.leagueSpartan(
            color: onPressed == null
                ? Colors.grey[400]
                : Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}



