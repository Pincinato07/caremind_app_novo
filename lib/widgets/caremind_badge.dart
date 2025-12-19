import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tipos de badge disponíveis
enum BadgeType {
  success,
  warning,
  error,
  info,
  primary,
  secondary,
}

/// Badge padronizado do CareMind
class CareMindBadge extends StatelessWidget {
  final String text;
  final BadgeType type;
  final bool outlined;
  final double? fontSize;
  final EdgeInsets? padding;

  const CareMindBadge({
    super.key,
    required this.text,
    this.type = BadgeType.primary,
    this.outlined = false,
    this.fontSize,
    this.padding,
  });

  Color get _backgroundColor {
    if (outlined) return Colors.transparent;

    switch (type) {
      case BadgeType.success:
        return AppColors.success;
      case BadgeType.warning:
        return AppColors.warning;
      case BadgeType.error:
        return AppColors.error;
      case BadgeType.info:
        return AppColors.info;
      case BadgeType.primary:
        return AppColors.primary;
      case BadgeType.secondary:
        return AppColors.textSecondary;
    }
  }

  Color get _textColor {
    if (outlined) {
      switch (type) {
        case BadgeType.success:
          return AppColors.success;
        case BadgeType.warning:
          return AppColors.warning;
        case BadgeType.error:
          return AppColors.error;
        case BadgeType.info:
          return AppColors.info;
        case BadgeType.primary:
          return AppColors.primary;
        case BadgeType.secondary:
          return AppColors.textSecondary;
      }
    }
    return Colors.white;
  }

  Color? get _borderColor {
    if (!outlined) return null;
    return _textColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: 4,
          ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: _borderColor != null
            ? Border.all(color: _borderColor!, width: 1.5)
            : null,
      ),
      child: Text(
        text,
        style: AppTextStyles.leagueSpartan(
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
      ),
    );
  }
}
