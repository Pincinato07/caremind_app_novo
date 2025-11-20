import 'package:flutter/material.dart';
import 'wave_background.dart';

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
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor ?? Colors.transparent,
      appBar: appBar != null
          ? PreferredSize(
              preferredSize: appBar!.preferredSize,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFA8B8FF).withValues(alpha: 0.95),
                      const Color(0xFF9B7EFF).withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: appBar,
              ),
            )
          : null,
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
          // Waves animadas
          const Align(
            alignment: Alignment.bottomCenter,
            child: AuthWaveBackground(),
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
                    Colors.white.withValues(alpha: 0.95),
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

