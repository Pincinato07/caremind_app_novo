import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Card com efeito glassmorphism melhorado com blur forte
class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double? blurSigma;
  final double? opacity;
  final bool useGradient;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.blurSigma,
    this.opacity,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: blurSigma ?? 12.0,
            sigmaY: blurSigma ?? 12.0,
          ),
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              label: onTap != null ? 'Card interativo' : 'Card',
              hint: onTap != null ? 'Toque para executar ação' : null,
              button: onTap != null,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius ?? BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64.0),
                  child: Container(
                    padding: padding ?? const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // Usa degrade ou cor sólida conforme configurado
                      color: useGradient 
                          ? null 
                          : Colors.white.withValues(alpha: opacity ?? 0.3),
                      gradient: useGradient 
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: opacity ?? 0.3),
                                Colors.white.withValues(alpha: (opacity ?? 0.3) * 0.8),
                                Colors.white.withValues(alpha: (opacity ?? 0.3) * 0.4),
                              ],
                              stops: const [0.0, 0.3, 1.0],
                            )
                          : null,
                      borderRadius: borderRadius ?? BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor ?? Colors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        // Sombra mais escura para melhor contraste
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                          spreadRadius: 0,
                        ),
                        // Brilho sutil nas bordas superior
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, -5),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
