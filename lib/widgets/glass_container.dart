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

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(18),
          child: Stack(
            children: [
              // Neutral underlay
              Positioned.fill(
                child: Container(color: Colors.white.withValues(alpha: 0.08)),
              ),
              // BackdropFilter para blur
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  width: width ?? screenW * 0.85,
                  constraints: BoxConstraints(
                    maxWidth: maxWidth ?? 380,
                    maxHeight: maxHeight ?? screenH * 0.8,
                  ),
                  padding: pad,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: borderRadius ?? BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.15),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  foregroundDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.25),
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.2, 0.6],
                    ),
                  ),
                  child: child,
                ),
              ),
              // Top glow line
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom inner shadow
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 18,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x0F000000),
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
    );
  }
}



