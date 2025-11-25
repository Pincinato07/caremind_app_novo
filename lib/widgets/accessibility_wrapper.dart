import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../core/injection/injection.dart';
import '../services/accessibility_service.dart';

/// Wrapper para aplicar configurações de acessibilidade globalmente
/// Aplica escala de fonte, alto contraste e semântica
class AccessibilityWrapper extends StatefulWidget {
  final Widget child;

  const AccessibilityWrapper({
    super.key,
    required this.child,
  });

  @override
  State<AccessibilityWrapper> createState() => _AccessibilityWrapperState();
}

class _AccessibilityWrapperState extends State<AccessibilityWrapper> {
  late SettingsService _settingsService;

  @override
  void initState() {
    super.initState();
    _settingsService = getIt<SettingsService>();
    _settingsService.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    // Atualiza configurações do AccessibilityService quando mudam
    AccessibilityService.updateSettingsService();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final fontScale = _settingsService.accessibilityFontScale;
        final highContrast = _settingsService.accessibilityHighContrast;

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: fontScale,
          ),
          child: _HighContrastWrapper(
            enabled: highContrast,
            child: Semantics(
              // Semântica global para leitores de tela
              label: 'CareMind - Aplicativo de gerenciamento de medicamentos',
              hint: 'Navegue pelas telas usando gestos ou comandos de voz',
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper para aplicar alto contraste quando habilitado
class _HighContrastWrapper extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _HighContrastWrapper({
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          // Cores de alto contraste (WCAG AAA)
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Colors.white,
          onSecondary: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
          background: Colors.black,
          onBackground: Colors.white,
          error: Colors.red,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.black,
        dividerColor: Colors.white,
        // Bordas mais grossas para melhor visibilidade
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white, width: 3),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white, width: 3),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white, width: 4),
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        child: child,
      ),
    );
  }
}

