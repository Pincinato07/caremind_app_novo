import 'dart:ui';
import 'package:flutter/material.dart';

/// Widget reutilizável para criar efeito glassmorphism
/// Segue o mesmo padrão das telas de auth e onboarding
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? maxWidth;
  final double? maxHeight;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.maxWidth,
    this.maxHeight,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final pad = padding ?? EdgeInsets.all((screenW * 0.025).clamp(16.0, 28.0));

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.circular(18),
            child: Stack(
              children: [
                // Fundo mais sólido para melhor contraste
                Positioned.fill(
                  child: Container(color: Colors.white.withValues(alpha: 0.15)),
                ),
                // BackdropFilter para blur com intensidade aumentada
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: width ?? screenW * 0.85,
                    constraints: BoxConstraints(
                      maxWidth: maxWidth ?? 380,
                      maxHeight: maxHeight ?? screenH * 0.8,
                    ),
                    padding: pad,
                    decoration: BoxDecoration(
                      // Cor mais opaca para melhor legibilidade
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: borderRadius ?? BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        // Sombra mais forte para melhor definição
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                        // Brilho sutil no topo
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    foregroundDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.4),
                          Colors.white.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.3, 0.7],
                      ),
                    ),
                    child: child,
                  ),
                ),
                // Top glow line mais destacado
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom inner shadow mais forte
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 20,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x1A000000),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
