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
            textScaler: TextScaler.linear(fontScale),
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

    // Aplicar filtro de alto contraste sobre todo o conteúdo
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        // Aumentar contraste e saturação
        1.5, 0, 0, 0, 0, // Red channel
        0, 1.5, 0, 0, 0, // Green channel
        0, 0, 1.5, 0, 0, // Blue channel
        0, 0, 0, 1, 0, // Alpha channel
      ]),
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          colorScheme: Theme.of(context).colorScheme.copyWith(
                // Cores de alto contraste (WCAG AAA)
                primary: Colors.white,
                onPrimary: Colors.black,
                secondary: Colors.white,
                onSecondary: Colors.black,
                surface: Colors.black,
                onSurface: Colors.white,
                error: Colors.red.shade900,
                onError: Colors.white,
              ),
          scaffoldBackgroundColor: Colors.black,
          cardColor: const Color(0xFF1A1A1A),
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          child: child,
        ),
      ),
    );
  }
}
