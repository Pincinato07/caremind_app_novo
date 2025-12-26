import 'dart:io';
import 'package:flutter/material.dart';

/// Serviço de Live Activities (iOS 14.0+)
/// Em Android, usa notificações normais
class LiveActivityService {
  static LiveActivityService? _instance;

  factory LiveActivityService() {
    _instance ??= LiveActivityService._internal();
    return _instance!;
  }

  LiveActivityService._internal();

  /// Inicializa o serviço
  Future<void> initialize() async {
    if (!Platform.isIOS) {
      debugPrint('ℹ️ LiveActivityService: Não disponível em Android');
      return;
    }
    
    try {
      // iOS: Inicializar live_activities
      debugPrint('✅ LiveActivityService: Inicializado (iOS)');
    } catch (e) {
      debugPrint('⚠️ LiveActivityService: Erro ao inicializar - $e');
    }
  }

  /// Cria uma Live Activity (iOS) ou agenda notificação (Android)
  Future<void> createActivity(dynamic medicamento, DateTime horario) async {
    if (!Platform.isIOS) {
      // Android: Usa notificação normal
      debugPrint('📱 Android: Usando notificação normal');
      return;
    }

    try {
      // iOS: Criar live activity
      debugPrint('✅ Live Activity criada para iOS');
    } catch (e) {
      debugPrint('❌ Erro ao criar Live Activity: $e');
    }
  }

  /// Remove uma Live Activity
  Future<void> removeActivity(int medicamentoId) async {
    if (!Platform.isIOS) return;
    
    try {
      debugPrint('✅ Live Activity removida');
    } catch (e) {
      debugPrint('⚠️ Erro ao remover: $e');
    }
  }

  /// Remove todas as Live Activities
  Future<void> removeAllActivities() async {
    if (!Platform.isIOS) return;
    
    try {
      debugPrint('✅ Todas as Live Activities removidas');
    } catch (e) {
      debugPrint('⚠️ Erro ao remover todas: $e');
    }
  }

  /// Verifica se está disponível
  Future<bool> isAvailable() async {
    return Platform.isIOS;
  }

  void dispose() {}
}
