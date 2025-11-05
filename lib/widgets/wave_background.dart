import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';
import 'package:caremind/services/wave_animation_service.dart';

class WaveBackground extends StatefulWidget {
  final double height;
  final double waveAmplitude;
  final List<Color> gradientColors;
  final List<double> stops;
  final List<int> durations;
  final List<double> heightPercentages;
  // Parâmetro mantido para compatibilidade, mas não é mais usado
  final String? stateId;
  
  const WaveBackground({
    Key? key,
    this.height = 260,
    this.waveAmplitude = 32,
    this.gradientColors = const [
      Color(0x400400BA),
      Color(0x400400BA),
      Color(0x590400BA),
      Color(0x590400BA),
      Color(0x730400BA),
      Color(0x730400BA),
    ],
    this.stops = const [0.0, 0.5, 0.5, 0.8, 0.8, 1.0],
    this.durations = const [16000, 22000, 28000],
    this.heightPercentages = const [0.42, 0.52, 0.62],
    this.stateId,
  }) : super(key: key);

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground> {
  final WaveAnimationService _waveService = WaveAnimationService();
  
  @override
  void initState() {
    super.initState();
    // Garante que o serviço de animação está rodando
    _waveService.addListener(_updateWave);
  }
  
  @override
  void dispose() {
    _waveService.removeListener(_updateWave);
    super.dispose();
  }
  
  void _updateWave() {
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  void didUpdateWidget(WaveBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Não é mais necessário sincronizar manualmente
  }

  @override
  Widget build(BuildContext context) {
    final waveValue = _waveService.currentValue;
    
    return AnimatedBuilder(
      animation: _waveService.waveValue,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: WaveWidget(
            config: CustomConfig(
              gradients: [
                [widget.gradientColors[0], widget.gradientColors[1]],
                [widget.gradientColors[2], widget.gradientColors[3]],
                [widget.gradientColors[4], widget.gradientColors[5]],
              ],
              durations: widget.durations,
              heightPercentages: widget.heightPercentages,
              blur: MaskFilter.blur(BlurStyle.solid, 10),
              gradientBegin: Alignment.topCenter,
              gradientEnd: Alignment.bottomCenter,
            ),
            size: Size(MediaQuery.of(context).size.width, widget.height),
            backgroundColor: Colors.transparent,
            waveAmplitude: widget.waveAmplitude,
            wavePhase: waveValue * 2 * pi,
            waveFrequency: 0.8,
          ),
        );
      },
    );
  }
}

// Versão otimizada para o AuthShell
class AuthWaveBackground extends StatelessWidget {
  const AuthWaveBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const WaveBackground(
      height: 260,
      waveAmplitude: 32,
      gradientColors: [
        Color(0x400400BA),
        Color(0x400400BA),
        Color(0x590400BA),
        Color(0x590400BA),
        Color(0x800400BA),
        Color(0x800400BA),
      ],
      stops: [0.0, 0.5, 0.5, 0.8, 0.8, 1.0],
      durations: [16000, 22000, 28000],
      heightPercentages: [0.42, 0.52, 0.62],
    );
  }
}

// Versão otimizada para o Onboarding
class OnboardingWaveBackground extends StatelessWidget {
  const OnboardingWaveBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const WaveBackground(
      height: 300,
      waveAmplitude: 32,
      gradientColors: [
        Color(0x400400BA),
        Color(0x400400BA),
        Color(0x590400BA),
        Color(0x590400BA),
        Color(0x800400BA),
        Color(0x800400BA),
      ],
      stops: [0.0, 0.5, 0.5, 0.8, 0.8, 1.0],
      durations: [16000, 22000, 28000],
      heightPercentages: [0.42, 0.52, 0.62],
    );
  }
}
