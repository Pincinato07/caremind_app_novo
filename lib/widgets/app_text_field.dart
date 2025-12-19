import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Campo de texto padronizado com estilo glassmorphism
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        label: label ?? hint ?? 'Campo de texto',
        hint: hint ?? 'Digite o texto',
        textField: true,
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          onChanged: onChanged,
          style: AppTextStyles.leagueSpartan(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: AppTextStyles.leagueSpartan(
              color: AppColors.textHint,
              fontSize: 16,
            ),
            labelStyle: AppTextStyles.leagueSpartan(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            prefixIcon: prefixIcon != null
                ? IconTheme(
                    data: const IconThemeData(color: AppColors.textSecondary),
                    child: prefixIcon!,
                  )
                : null,
            suffixIcon: suffixIcon != null
                ? IconTheme(
                    data: const IconThemeData(color: AppColors.textSecondary),
                    child: suffixIcon!,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }
}
