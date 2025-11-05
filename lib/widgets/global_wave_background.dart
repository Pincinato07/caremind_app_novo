import 'package:flutter/material.dart';
import 'wave_background.dart';

class GlobalWaveBackground extends StatelessWidget {
  const GlobalWaveBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradiente de fundo
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFA8B8FF), // Lilás claro
                Color(0xFF0400BA), // Azul escuro
              ],
            ),
          ),
        ),
        
        // Ondas animadas
        const WaveBackground(
          height: double.infinity,
          waveAmplitude: 32,
          gradientColors: [
            Color(0x33FFFFFF), // Branco com 20% de opacidade
            Color(0x33FFFFFF),
            Color(0x4DFFFFFF), // Branco com 30% de opacidade
            Color(0x4DFFFFFF),
            Color(0x66FFFFFF), // Branco com 40% de opacidade
            Color(0x66FFFFFF),
          ],
          stops: [0.0, 0.5, 0.5, 0.8, 0.8, 1.0],
          durations: [35000, 20000, 25000],
          heightPercentages: [0.3, 0.35, 0.4],
        ),
      ],
    );
  }
}
