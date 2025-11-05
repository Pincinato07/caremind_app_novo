import 'dart:async';
import 'package:flutter/material.dart';

class WaveAnimationService {
  static final WaveAnimationService _instance = WaveAnimationService._internal();
  
  // Controla o valor da animação das ondas (0.0 a 1.0)
  final ValueNotifier<double> waveValue = ValueNotifier(0.0);
  
  factory WaveAnimationService() => _instance;
  
  WaveAnimationService._internal() {
    // Inicia a animação
    _startAnimation();
  }
  
  void _startAnimation() {
    // Atualiza o valor da animação a cada frame
    void update(Timer timer) {
      // Atualiza o valor da animação (30 segundos para completar um ciclo)
      _instance.waveValue.value = (DateTime.now().millisecondsSinceEpoch % 30000) / 30000.0;
    }
    
    // Usa um timer periódico para atualizar a animação
    Timer.periodic(const Duration(milliseconds: 16), update);
  }
  
  // Obtém o valor atual da animação
  double get currentValue => waveValue.value;
  
  // Adiciona um listener para a animação
  void addListener(VoidCallback listener) {
    waveValue.addListener(listener);
  }
  
  // Remove um listener da animação
  void removeListener(VoidCallback listener) {
    waveValue.removeListener(listener);
  }
  
  // Para a animação (opcional)
  void dispose() {
    waveValue.dispose();
  }
}
