import 'package:flutter/material.dart';
import 'wave_background.dart';
import '../core/injection/injection.dart';
import '../services/settings_service.dart';

/// Scaffold padronizado com fundo gradiente e waves
/// Usa o mesmo padrão das telas de auth e onboarding
class AppScaffoldWithWaves extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final Widget? bottomNavigationBar;

  const AppScaffoldWithWaves({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final settingsService = getIt<SettingsService>();

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor ?? Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: Stack(
        children: [
          // Fundo gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFA8B8FF), Color(0xFF9B7EFF)],
              ),
            ),
          ),
          // Waves animadas (condicional)
          ListenableBuilder(
            listenable: settingsService,
            builder: (context, _) {
              if (!settingsService.wavesEnabled) {
                return const SizedBox.shrink();
              }
              return const Align(
                alignment: Alignment.bottomCenter,
                child: AuthWaveBackground(),
              );
            },
          ),
          // Conteúdo
          body,
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar != null
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.98),
                    Colors.white,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: bottomNavigationBar,
            )
          : null,
    );
  }
}

