import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// Variantes de card disponíveis
enum CardVariant {
  glass,    // Glassmorphism (para fundos com gradiente)
  solid,    // Card sólido branco (para fundos claros)
  elevated, // Card com elevação (para destaque)
}

/// Card unificado do CareMind
/// Substitui GlassCard e _surfaceCard para consistência
class CareMindCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final CardVariant variant;
  final Color? backgroundColor;
  final double? elevation;
  final List<BoxShadow>? boxShadow;

  const CareMindCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.variant = CardVariant.solid,
    this.backgroundColor,
    this.elevation,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case CardVariant.glass:
        return GlassCard(
          onTap: onTap,
          padding: padding,
          borderRadius: borderRadius,
          borderColor: borderColor,
          child: child,
        );

      case CardVariant.solid:
        return _buildSolidCard();

      case CardVariant.elevated:
        return _buildElevatedCard();
    }
  }

  Widget _buildSolidCard() {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          label: onTap != null ? 'Card interativo' : 'Card',
          hint: onTap != null ? 'Toque para executar ação' : null,
          button: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius ?? AppBorderRadius.mediumAll,
            child: Container(
              padding: padding ?? const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: backgroundColor ?? AppColors.surface,
                borderRadius: borderRadius ?? AppBorderRadius.mediumAll,
                border: Border.all(
                  color: borderColor ?? AppColors.border,
                  width: 1.5,
                ),
                boxShadow: boxShadow ?? AppShadows.small,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElevatedCard() {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        elevation: elevation ?? 4,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        borderRadius: borderRadius ?? AppBorderRadius.mediumAll,
        child: Semantics(
          label: onTap != null ? 'Card interativo' : 'Card',
          hint: onTap != null ? 'Toque para executar ação' : null,
          button: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius ?? AppBorderRadius.mediumAll,
            child: Container(
              padding: padding ?? const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: backgroundColor ?? AppColors.surface,
                borderRadius: borderRadius ?? AppBorderRadius.mediumAll,
                border: borderColor != null
                    ? Border.all(color: borderColor!, width: 1.5)
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

