import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cores padronizadas do aplicativo
class AppColors {
  static const Color primary = Color(0xFF0F172A);
  static const Color primaryDark = Color(0xFF0B1222);
  static const Color primaryLight = Color(0xFF1F2A44);
  
  static const Color accent = Color(0xFFFF6B4A);
  static const Color success = Color(0xFF2EC27E);
  static const Color warning = Color(0xFFF4A01C);
  static const Color error = Color(0xFFDC4B4B);
  static const Color info = Color(0xFF3B82F6);
  
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color card = Colors.white;
  
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF4B5565);
  static const Color textHint = Color(0xFF6B7280); // WCAG AA compliant: 4.6:1
  static const Color textOnPrimary = Colors.white;
  
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFE4E7EC);
  
  static const Color disabled = Color(0xFFE5E7EB);
  static const Color disabledText = Color(0xFF9AA4B2);
}

/// Estilos de texto padronizados
class AppTextStyles {
  static const String fontFamily = 'Manrope';

  static const TextStyle displayLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle displayMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle displaySmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);

  static const TextStyle headlineLarge = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle headlineMedium = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle headlineSmall = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);

  static const TextStyle titleLarge = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle titleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.textPrimary, fontFamily: fontFamily);

  static const TextStyle bodyLarge = TextStyle(fontSize: 16, height: 1.5, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary, fontFamily: fontFamily);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary, fontFamily: fontFamily);

  static const TextStyle labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textOnPrimary, fontFamily: fontFamily);
  static const TextStyle labelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: fontFamily);

  static const TextStyle link = TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, fontFamily: fontFamily);
}

/// Bordas e raios padronizados
class AppBorderRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xlarge = 24.0;
  
  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumAll = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
  static const BorderRadius xlargeAll = BorderRadius.all(Radius.circular(xlarge));
}

/// Sombras padronizadas
class AppShadows {
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 4.0,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 8.0,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> large = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 16.0,
      offset: Offset(0, 8),
    ),
  ];
}

/// Espaçamentos padronizados
class AppSpacing {
  static const double xsmall = 4.0;
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double xlarge = 32.0;
  static const double xxlarge = 48.0;
  static const double bottomNavBarPadding = 96.0;
}

/// Tema principal do aplicativo
class AppTheme {
  // Construtor privado para evitar instanciação
  AppTheme._();
  
  static ThemeData get themeData {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      displaySmall: AppTextStyles.displaySmall,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.titleSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textOnPrimary,
        brightness: Brightness.light,
        outline: AppColors.border,
      ),
      
      // Configurações de tipografia
      textTheme: textTheme,
      
      // Configurações de AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnPrimary,
          fontFamily: AppTextStyles.fontFamily,
        ),
        iconTheme: IconThemeData(color: AppColors.textOnPrimary),
      ),
      
      // Configurações de botões
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.smallAll),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.smallAll),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      
      // Configurações de cards
      cardTheme: base.cardTheme.copyWith(
        color: AppColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumAll,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      
      // Configurações de campos de formulário
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: AppBorderRadius.smallAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppBorderRadius.smallAll,
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppBorderRadius.smallAll,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.smallAll,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.smallAll,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2.0,
          ),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textHint),
        errorStyle: const TextStyle(color: AppColors.error),
      ),
      
      // Configurações de diálogos
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: AppColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumAll,
        ),
        titleTextStyle: AppTextStyles.headlineSmall,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),
      
      // Configurações de divisores
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1.0,
        space: 1.0,
      ),
      
      // Configurações de ícones
      iconTheme: const IconThemeData(
        color: AppColors.primary,
        size: 24.0,
      ),
      
      // Configurações de snackbar
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: TextStyle(color: AppColors.textOnPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumAll,
        ),
      ),
      
      // Configurações de botão flutuante
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 2,
      ),
      
      // Configurações de tabs
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2.0,
          ),
        ),
      ),
      
      // Configurações de chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        disabledColor: AppColors.disabled,
        selectedColor: AppColors.primary.withOpacity(0.08),
        checkmarkColor: AppColors.primary,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: 4.0,
        ),
        labelStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.0,
        ),
        secondaryLabelStyle: TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: 14.0,
        ),
        brightness: Brightness.light,
      ),
    );
  }
}