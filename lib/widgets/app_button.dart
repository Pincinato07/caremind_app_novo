import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
  return SizedBox(
    height: height ?? 56,
    width: width,
      child: Semantics(
        label: label,
        hint: isLoading ? 'Carregando...' : 'Toque para executar ação',
        button: true,
        enabled: !isLoading && onPressed != null,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.disabled;
              }
              if (states.contains(WidgetState.pressed)) {
                return AppColors.primaryDark;
              }
              if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
                return AppColors.primaryLight;
              }
              return AppColors.primary;
            }),
            foregroundColor: WidgetStateProperty.all(AppColors.textOnPrimary),
            overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.08)),
            elevation: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return 0;
              if (states.contains(WidgetState.pressed)) return 2;
              return 0;
            }),
            shadowColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.12)),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
            textStyle: WidgetStateProperty.all(
              AppTextStyles.leagueSpartan(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(label),
        ),
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
    height: height ?? 56,
    width: width,
      child: Semantics(
        label: label,
        hint: onPressed == null ? 'Botão desabilitado' : 'Toque para executar ação',
        button: true,
        enabled: onPressed != null,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: onPressed == null ? AppColors.disabled : AppColors.primary,
              width: 2,
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: onPressed == null ? AppColors.disabledText : AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: AppTextStyles.leagueSpartan(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

