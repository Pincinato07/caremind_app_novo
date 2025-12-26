import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

/// Serviço para detectar movimento de "shake" (chacoalhar)
/// Usado para acionar SOS em situações de emergência
class ShakeDetectorService {
  static ShakeDetectorService? _instance;
  
  StreamSubscription? _accelerometerSubscription;
  bool _isListening = false;
  
  // Callbacks
  Function? _onShakeDetected;
  
  factory ShakeDetectorService() {
    _instance ??= ShakeDetectorService._internal();
    return _instance!;
  }
  
  ShakeDetectorService._internal();
  
  /// Inicia a detecção de shake
  void startListening(Function onShakeDetected) {
    if (_isListening) return;
    
    _onShakeDetected = onShakeDetected;
    _isListening = true;
    
    debugPrint('⚠️ ShakeDetector: Sensor não disponível (modo stub)');
  }
  
  /// Para a detecção de shake
  void stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isListening = false;
  }
  
  /// Verifica se está ouvindo
  bool get isListening => _isListening;
  
  /// Simula um shake (para testes sem sensor)
  void simulateShake() {
    if (_isListening && _onShakeDetected != null) {
      _triggerSOS();
    }
  }
  
  /// Aciona o SOS
  Future<void> _triggerSOS() async {
    debugPrint('🚨 ShakeDetector: SOS ACIONADO!');
    
    // Feedback de vibração
    try {
      if (await Vibration.hasVibrator() == true) {
        await Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
      }
    } catch (e) {
      debugPrint('⚠️ Erro na vibração: $e');
    }
    
    // Chama callback
    if (_onShakeDetected != null) {
      _onShakeDetected!();
    }
  }
  
  /// Dispose do serviço
  void dispose() {
    stopListening();
    _instance = null;
  }
}
