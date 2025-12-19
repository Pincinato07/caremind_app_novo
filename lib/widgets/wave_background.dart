import 'dart:math';
import 'package:flutter/material.dart';

class WaveBackground extends StatefulWidget {
  final double height;
  final double waveAmplitude;
  final List<Color> gradientColors;
  final List<double> stops;
  final List<int> durations;
  final List<double> heightPercentages;
  final String? stateId;

  const WaveBackground({
    Key? key,
    this.height = 260,
    this.waveAmplitude = 12,
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

class _WaveBackgroundState extends State<WaveBackground>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _controllers = [];
    _animations = [];

    for (int i = 0; i < widget.durations.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.durations[i]),
      )..repeat();

      _controllers.add(controller);
      _animations.add(
        Tween<double>(begin: 0, end: 2 * pi).animate(controller),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ListenableBuilder(
          listenable: Listenable.merge(_controllers),
          builder: (context, child) {
            return CustomPaint(
              size: Size(MediaQuery.of(context).size.width, widget.height),
              painter: WavePainter(
                wavePhases: _animations.map((a) => a.value).toList(),
                waveAmplitude: widget.waveAmplitude,
                heightPercentages: widget.heightPercentages,
                colors: [
                  [widget.gradientColors[0], widget.gradientColors[1]],
                  [widget.gradientColors[2], widget.gradientColors[3]],
                  [widget.gradientColors[4], widget.gradientColors[5]],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final List<double> wavePhases;
  final double waveAmplitude;
  final List<double> heightPercentages;
  final List<List<Color>> colors;

  WavePainter({
    required this.wavePhases,
    required this.waveAmplitude,
    required this.heightPercentages,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = wavePhases.length - 1; i >= 0; i--) {
      _drawWave(canvas, size, i);
    }
  }

  void _drawWave(Canvas canvas, Size size, int index) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors[index],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 10);

    final path = Path();
    final baseHeight = size.height * heightPercentages[index];

    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);

    for (double x = 0; x <= size.width; x++) {
      final y = baseHeight +
          sin((x / size.width * 1.5 * pi) + wavePhases[index]) * waveAmplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.wavePhases != wavePhases;
  }
}

class AuthWaveBackground extends StatelessWidget {
  const AuthWaveBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const WaveBackground(
      height: 260,
      waveAmplitude: 12,
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

class OnboardingWaveBackground extends StatelessWidget {
  const OnboardingWaveBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const WaveBackground(
      height: 300,
      waveAmplitude: 12,
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
