import 'package:flutter/material.dart';
import 'dart:async';

/// Widget de Timer Circular para Modo Crítico
/// Mostra contagem regressiva visual quando faltam < 15 minutos
class CriticalModeTimer extends StatefulWidget {
  final DateTime? nextMedicationTime;
  final VoidCallback? onTimeArrived;

  const CriticalModeTimer({
    super.key,
    this.nextMedicationTime,
    this.onTimeArrived,
  });

  @override
  State<CriticalModeTimer> createState() => _CriticalModeTimerState();
}

class _CriticalModeTimerState extends State<CriticalModeTimer>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration? _timeRemaining;
  bool _isCriticalMode = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(CriticalModeTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nextMedicationTime != oldWidget.nextMedicationTime) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    
    if (widget.nextMedicationTime == null) {
      setState(() {
        _isCriticalMode = false;
        _timeRemaining = null;
      });
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimer();
    });
  }

  void _updateTimer() {
    if (!mounted) return;

    final now = DateTime.now();
    final nextTime = widget.nextMedicationTime!;
    final difference = nextTime.difference(now);

    if (difference.isNegative) {
      // Horário já passou
      setState(() {
        _isCriticalMode = false;
        _timeRemaining = null;
      });
      _timer?.cancel();
      return;
    }

    // Modo Crítico: faltam menos de 15 minutos
    final isCritical = difference.inMinutes < 15 && difference.inMinutes >= 0;

    setState(() {
      _isCriticalMode = isCritical;
      _timeRemaining = difference;

      if (isCritical) {
        // Calcula progresso (15 min = 0%, 0 min = 100%)
        final totalSeconds = 15 * 60;
        final remainingSeconds = difference.inSeconds;
        _progress = 1.0 - (remainingSeconds / totalSeconds);
        
        // Se chegou no horário
        if (difference.inSeconds <= 0 && widget.onTimeArrived != null) {
          widget.onTimeArrived!();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCriticalMode || _timeRemaining == null) {
      return const SizedBox.shrink();
    }

    final minutes = _timeRemaining!.inMinutes;
    final seconds = _timeRemaining!.inSeconds % 60;

    return Semantics(
      label: 'Modo Crítico: Tempo restante',
      hint: '$minutes minutos e $seconds segundos para o horário do remédio',
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo progressivo pulsante
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Colors.red.shade400,
                  Colors.red.shade700,
                  Colors.red.shade400,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 6,
                backgroundColor: Colors.red.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade900),
              ),
            ),
          ),

          // Texto de contagem
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$minutes',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
              Text(
                'min',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),

          // Animação de pulso (sutil)
          if (_progress < 1.0)
            AnimatedBuilder(
              animation: Listenable.merge([
                AnimationController(
                  vsync: this,
                  duration: const Duration(seconds: 2),
                )..repeat(reverse: true),
              ]),
              builder: (context, child) {
                return Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

