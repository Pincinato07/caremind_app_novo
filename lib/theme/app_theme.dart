import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cores padronizadas do aplicativo
class AppColors {
  // Cores principais
  static const Color primary = Color(0xFF0400BA);
  static const Color primaryDark = Color(0xFF020054);
  static const Color primaryLight = Color(0xFF0600E0);
  
  // Cores de destaque
  static const Color accent = Color(0xFF0600E0);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);
  
  // Cores de fundo
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color card = Colors.white;
  
  // Cores de texto
  static const Color textPrimary = Color(0xFF171717);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Colors.white;
  
  // Cores de borda e divisores
  // 12% preto para divisores: ARGB ~ 0x1F000000
  static const Color divider = Color(0x1F000000);
  static const Color border = Color(0xFFE0E0E0);
  
  // Cores de feedback
  static const Color disabled = Color(0xFFE0E0E0);
  static const Color disabledText = Color(0xFF9E9E9E);
}

/// Estilos de texto padronizados
class AppTextStyles {
  static const String fontFamily = 'LeagueSpartan';

  // Tamanhos baseados no DS
  static const TextStyle displayLarge = TextStyle(fontSize: 57, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle displayMedium = TextStyle(fontSize: 45, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle displaySmall = TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);

  static const TextStyle headlineLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle headlineMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle headlineSmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);

  static const TextStyle titleLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle titleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.textPrimary, fontFamily: fontFamily);

  static const TextStyle bodyLarge = TextStyle(fontSize: 16, height: 1.6, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary, fontFamily: fontFamily);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, height: 1.5, color: AppColors.textHint, fontFamily: fontFamily);

  static const TextStyle labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textOnPrimary, fontFamily: fontFamily);
  static const TextStyle labelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: fontFamily);

  static const TextStyle link = TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, fontFamily: fontFamily);

  // Helper methods para criar TextStyles com a fonte LeagueSpartan já carregada
  // Estes métodos usam a fonte do tema, evitando downloads repetidos
  static TextStyle leagueSpartan({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  // TextStyles pré-definidos comuns para uso rápido
  static TextStyle get h1 => leagueSpartan(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2);
  static TextStyle get h2 => leagueSpartan(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2);
  static TextStyle get h3 => leagueSpartan(fontSize: 20, fontWeight: FontWeight.w600, height: 1.25);
  static TextStyle get h4 => leagueSpartan(fontSize: 18, fontWeight: FontWeight.w600, height: 1.25);
  static TextStyle get h5 => leagueSpartan(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25);
  static TextStyle get h6 => leagueSpartan(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25);
  
  static TextStyle get body1 => leagueSpartan(fontSize: 16, height: 1.6);
  static TextStyle get body2 => leagueSpartan(fontSize: 14, height: 1.6);
  static TextStyle get caption => leagueSpartan(fontSize: 12, height: 1.5);
  static TextStyle get overline => leagueSpartan(fontSize: 10, fontWeight: FontWeight.w600, height: 1.5);
  
  static TextStyle get button => leagueSpartan(fontSize: 14, fontWeight: FontWeight.w600);
  static TextStyle get subtitle1 => leagueSpartan(fontSize: 16, fontWeight: FontWeight.w500);
  static TextStyle get subtitle2 => leagueSpartan(fontSize: 14, fontWeight: FontWeight.w500);
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
  /// Espaço mínimo necessário para não sobrepor a navbar inferior (inclui SafeArea)
  static const double bottomNavBarPadding = 100.0;
}

/// Tema principal do aplicativo
class AppTheme {
  // Construtor privado para evitar instanciação
  AppTheme._();
  
  static ThemeData get themeData {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.leagueSpartanTextTheme(base.textTheme).copyWith(
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
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textOnPrimary,
        brightness: Brightness.light,
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
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumAll,
        ),
      ),
      
      // Configurações de campos de formulário
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
        selectedColor: Color(0x1A0400BA),
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
