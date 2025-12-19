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

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF0B1222);
  static const Color darkSurface = Color(0xFF1A1F35);
  static const Color darkCard = Color(0xFF1F2A44);
  static const Color darkPrimary = Color(0xFF4A90E2);
  static const Color darkPrimaryLight = Color(0xFF5BA3F5);
  
  static const Color darkTextPrimary = Color(0xFFF5F7FB);
  static const Color darkTextSecondary = Color(0xFFB8C5D6);
  static const Color darkTextHint = Color(0xFF8B9DB0);
  static const Color darkTextOnPrimary = Colors.white;
  
  static const Color darkDivider = Color(0xFF2D3A52);
  static const Color darkBorder = Color(0xFF2D3A52);
  
  static const Color darkDisabled = Color(0xFF2D3A52);
  static const Color darkDisabledText = Color(0xFF6B7A8F);
}

/// Estilos de texto padronizados
class AppTextStyles {
  static const String fontFamily = 'Manrope';

  /// Helper para aplicar escala de texto baseado nas configurações de acessibilidade do sistema
  /// WCAG 1.4.4: Respeitar preferências de tamanho de texto do usuário
  static double scaleFontSize(BuildContext context, double baseFontSize) {
    final textScaler = MediaQuery.of(context).textScaler;
    return textScaler.scale(baseFontSize);
  }

  static const TextStyle displayLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle displayMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle displaySmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);

  // Headline (Títulos de seções)
  static const TextStyle headlineLarge = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle headlineMedium = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle headlineSmall = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.textPrimary, fontFamily: fontFamily);

  // Title (Subtítulos e labels importantes)
  static const TextStyle titleLarge = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.textPrimary, fontFamily: fontFamily);
  static const TextStyle titleMedium = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.textPrimary, fontFamily: fontFamily); // WCAG: Aumentado de 16px para 18px
  static const TextStyle titleSmall = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.textPrimary, fontFamily: fontFamily); // WCAG: Aumentado de 14px para 16px

  // Body (Texto corrido)
  static const TextStyle bodyLarge = TextStyle(fontSize: 18, height: 1.5, color: AppColors.textPrimary, fontFamily: fontFamily); // WCAG: Aumentado de 16px para 18px
  static const TextStyle bodyMedium = TextStyle(fontSize: 16, height: 1.5, color: AppColors.textSecondary, fontFamily: fontFamily); // WCAG: Aumentado de 14px para 16px (mínimo para textos secundários)
  static const TextStyle bodySmall = TextStyle(fontSize: 16, height: 1.5, color: AppColors.textSecondary, fontFamily: fontFamily); // WCAG: Aumentado de 12px para 16px

  // Label (Botões e ações)
  static const TextStyle labelLarge = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textOnPrimary, fontFamily: fontFamily); // WCAG: Aumentado de 16px para 18px
  static const TextStyle labelMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: fontFamily); // WCAG: Aumentado de 14px para 16px
  static const TextStyle labelSmall = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: fontFamily); // WCAG: Aumentado de 12px para 16px

  // Caption (Legendas e informações secundárias)
  static const TextStyle caption = TextStyle(fontSize: 16, height: 1.4, color: AppColors.textHint, fontFamily: fontFamily); // WCAG: Aumentado de 12px para 16px

  // Link
  static const TextStyle link = TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, fontFamily: fontFamily); // WCAG: Aumentado de 14px para 16px

  // Método para League Spartan
  static TextStyle leagueSpartan({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.leagueSpartan(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }
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
/// REGRA: Use APENAS estes valores. Nunca valores hardcoded como EdgeInsets.all(24)
class AppSpacing {
  static const double xsmall = 4.0;
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double xlarge = 32.0;
  static const double xxlarge = 48.0;
  static const double bottomNavBarPadding = 96.0;
  
  /// Helpers para EdgeInsets comuns
  static const EdgeInsets paddingSmall = EdgeInsets.all(small);
  static const EdgeInsets paddingMedium = EdgeInsets.all(medium);
  static const EdgeInsets paddingLarge = EdgeInsets.all(large);
  static const EdgeInsets paddingXLarge = EdgeInsets.all(xlarge);
  
  static const EdgeInsets paddingHorizontal = EdgeInsets.symmetric(horizontal: medium);
  static const EdgeInsets paddingVertical = EdgeInsets.symmetric(vertical: medium);
  
  static const EdgeInsets paddingScreen = EdgeInsets.all(large);
  static const EdgeInsets paddingCard = EdgeInsets.all(medium);
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
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), // WCAG: Aumentado de 14px para 16px
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
        selectedColor: AppColors.primary.withValues(alpha: 0.08),
        checkmarkColor: AppColors.primary,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: 4.0,
        ),
        labelStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16.0, // WCAG: Aumentado de 14px para 16px
        ),
        secondaryLabelStyle: TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: 16.0, // WCAG: Aumentado de 14px para 16px
        ),
        brightness: Brightness.light,
      ),
    );
  }

  /// Tema escuro do aplicativo
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: AppColors.darkTextPrimary),
      displayMedium: AppTextStyles.displayMedium.copyWith(color: AppColors.darkTextPrimary),
      displaySmall: AppTextStyles.displaySmall.copyWith(color: AppColors.darkTextPrimary),
      headlineLarge: AppTextStyles.headlineLarge.copyWith(color: AppColors.darkTextPrimary),
      headlineMedium: AppTextStyles.headlineMedium.copyWith(color: AppColors.darkTextPrimary),
      headlineSmall: AppTextStyles.headlineSmall.copyWith(color: AppColors.darkTextPrimary),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: AppColors.darkTextPrimary),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: AppColors.darkTextPrimary),
      titleSmall: AppTextStyles.titleSmall.copyWith(color: AppColors.darkTextPrimary),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.darkTextPrimary),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: AppColors.darkTextSecondary),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: AppColors.darkTextOnPrimary),
    );

    return base.copyWith(
      colorScheme: ColorScheme.dark(
        primary: AppColors.darkPrimary,
        primaryContainer: AppColors.darkPrimaryLight,
        secondary: AppColors.accent,
        surface: AppColors.darkSurface,
        background: AppColors.darkBackground,
        error: AppColors.error,
        onPrimary: AppColors.darkTextOnPrimary,
        onSecondary: AppColors.darkTextOnPrimary,
        onSurface: AppColors.darkTextPrimary,
        onError: AppColors.darkTextOnPrimary,
        brightness: Brightness.dark,
        outline: AppColors.darkBorder,
      ),
      
      // Configurações de tipografia
      textTheme: textTheme,
      
      // Configurações de AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
          fontFamily: AppTextStyles.fontFamily,
        ),
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      ),
      
      // Configurações de botões
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkTextOnPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.smallAll),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), // WCAG: Aumentado de 14px para 16px
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          backgroundColor: AppColors.darkSurface,
          side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.smallAll),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      
      // Configurações de cards
      cardTheme: base.cardTheme.copyWith(
        color: AppColors.darkCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumAll,
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      
      // Configurações de campos de formulário
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: AppBorderRadius.smallAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppBorderRadius.smallAll,
          borderSide: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppBorderRadius.smallAll,
          borderSide: BorderSide(color: AppColors.darkPrimary, width: 2),
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
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        hintStyle: const TextStyle(color: AppColors.darkTextHint),
        errorStyle: const TextStyle(color: AppColors.error),
      ),
      
      // Configurações de diálogos
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: AppColors.darkSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumAll,
        ),
        titleTextStyle: AppTextStyles.headlineSmall.copyWith(color: AppColors.darkTextPrimary),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
      ),
      
      // Configurações de divisores
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1.0,
        space: 1.0,
      ),
      
      // Configurações de ícones
      iconTheme: const IconThemeData(
        color: AppColors.darkTextPrimary,
        size: 24.0,
      ),
      
      // Configurações de snackbar
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.darkSurface,
        contentTextStyle: TextStyle(color: AppColors.darkTextPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumAll,
        ),
      ),
      
      // Configurações de botão flutuante
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: AppColors.darkTextOnPrimary,
        elevation: 2,
      ),
      
      // Configurações de tabs
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: AppColors.darkPrimary,
        unselectedLabelColor: AppColors.darkTextSecondary,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: AppColors.darkPrimary,
            width: 2.0,
          ),
        ),
      ),
      
      // Configurações de chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface,
        disabledColor: AppColors.darkDisabled,
        selectedColor: AppColors.darkPrimary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.darkPrimary,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: 4.0,
        ),
        labelStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 16.0, // WCAG: Aumentado de 14px para 16px
        ),
        secondaryLabelStyle: TextStyle(
          color: AppColors.darkTextOnPrimary,
          fontSize: 16.0, // WCAG: Aumentado de 14px para 16px
        ),
        brightness: Brightness.dark,
      ),
      
      scaffoldBackgroundColor: AppColors.darkBackground,
    );
  }
}
