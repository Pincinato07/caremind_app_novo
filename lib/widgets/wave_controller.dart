import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';

class WaveState {
  final double progress;
  final int timestamp;
  
  WaveState({required this.progress, required this.timestamp});
  
  factory WaveState.now(double progress) {
    return WaveState(progress: progress, timestamp: DateTime.now().millisecondsSinceEpoch);
  }
  
  bool get isExpired {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age > 5 * 60 * 1000; // 5 minutos
  }
}

class WaveController {
  static final WaveController _instance = WaveController._internal();
  final Map<String, WaveState> _waveStates = {};
  
  // Controladores de animação ativos
  final Map<String, AnimationController> _activeControllers = {};
  
  factory WaveController() => _instance;
  
  WaveController._internal();
  
  WaveState? getState(String id) {
    final state = _waveStates[id];
    if (state != null && state.isExpired) {
      _waveStates.remove(id);
      return null;
    }
    return state;
  }
  
  void saveState(String id, double progress) {
    _waveStates[id] = WaveState.now(progress);
    
    // Limpa estados expirados
    _waveStates.removeWhere((key, state) => state.isExpired);
  }
  
  // Registra um controlador ativo
  void registerController(String id, AnimationController controller) {
    _activeControllers[id] = controller;
  }
  
  // Remove um controlador ativo
  void unregisterController(String id) {
    _activeControllers.remove(id);
  }
  
  // Sincroniza o estado entre controladores
  void syncControllers(String sourceId, String targetId) {
    final sourceController = _activeControllers[sourceId];
    final targetController = _activeControllers[targetId];
    
    if (sourceController != null && targetController != null) {
      // Usa um postFrameCallback para evitar problemas com o ciclo de vida
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          // Verifica se o targetController ainda está ativo
          if (_activeControllers[targetId] == targetController) {
            targetController.value = sourceController.value % 1.0;
          }
        } catch (e) {
          // Ignora erros de animação
        }
      });
    }
  }
  
  static const String authScreenId = 'auth_waves';
  static const String onboardingScreenId = 'onboarding_waves';
}
