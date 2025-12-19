import 'dart:async';
import 'package:flutter/material.dart';

/// Serviço otimizado para animação de ondas
/// Frequência reduzida de 16ms (60fps) para 33ms (30fps) - suficiente para animação suave
/// Isso reduz significativamente o uso de CPU e melhora a performance geral
class WaveAnimationService {
  static final WaveAnimationService _instance =
      WaveAnimationService._internal();

  // Controla o valor da animação das ondas (0.0 a 1.0)
  final ValueNotifier<double> waveValue = ValueNotifier(0.0);

  Timer? _timer;
  bool _isRunning = false;

  factory WaveAnimationService() => _instance;

  WaveAnimationService._internal() {
    // A animação será iniciada quando o primeiro listener for adicionado
  }

  void _startAnimation() {
    if (_isRunning) return;
    _isRunning = true;

    // Frequência otimizada: 33ms = ~30fps (suficiente para animação suave)
    // Redução de 60% no número de atualizações comparado a 16ms (60fps)
    _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      // Atualiza o valor da animação (30 segundos para completar um ciclo)
      waveValue.value =
          (DateTime.now().millisecondsSinceEpoch % 30000) / 30000.0;
    });
  }

  void _stopAnimation() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  // Obtém o valor atual da animação
  double get currentValue => waveValue.value;

  // Adiciona um listener para a animação
  void addListener(VoidCallback listener) {
    waveValue.addListener(listener);
    // Inicia animação quando o primeiro listener é adicionado
    if (!_isRunning) {
      _startAnimation();
    }
  }

  // Remove um listener da animação
  void removeListener(VoidCallback listener) {
    waveValue.removeListener(listener);
    // Para animação se não houver mais listeners
    // Nota: ValueNotifier não expõe hasListeners diretamente,
    // então mantemos a animação rodando enquanto houver pelo menos um listener
    // A animação será parada apenas no dispose()
  }

  // Para a animação
  void dispose() {
    _stopAnimation();
    waveValue.dispose();
  }
}
