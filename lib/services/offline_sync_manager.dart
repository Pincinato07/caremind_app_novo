import 'dart:async';
import 'package:flutter/foundation.dart';
import 'offline_cache_service.dart';
import 'ocr_offline_service.dart';
import 'medication_sync_service.dart';
import 'medicamento_service.dart';
import 'supabase_service.dart';
import 'package:get_it/get_it.dart';

/// Gerenciador centralizado de sincronização offline
///
/// Responsável por:
/// - Inicializar listeners de conectividade
/// - Processar imagens OCR pendentes quando voltar online
/// - Sincronizar ações de medicamentos pendentes
class OfflineSyncManager {
  static bool _initialized = false;
  static StreamSubscription<bool>? _connectivitySubscription;
  static bool _isProcessing = false; // CORRIGIDO: Flag para evitar processamento concorrente

  /// Inicializar gerenciador de sincronização
  ///
  /// Deve ser chamado após autenticação do usuário
  static Future<void> initialize(String userId) async {
    if (_initialized) {
      debugPrint('⚠️ OfflineSyncManager: Já inicializado');
      return;
    }

    try {
      debugPrint('🔄 OfflineSyncManager: Inicializando para usuário $userId');

      // Processar pendências existentes se já estiver online
      final isOnline = await OfflineCacheService.isOnline();
      if (isOnline) {
        await processPendingData(userId);
      }

      // Configurar listener de conectividade
      _setupConnectivityListener(userId);

      _initialized = true;
      debugPrint('✅ OfflineSyncManager: Inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ OfflineSyncManager: Erro ao inicializar: $e');
    }
  }

  /// Configurar listener de conectividade
  static void _setupConnectivityListener(String userId) {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = OfflineCacheService.connectivityStream.listen(
      (isOnline) async {
        if (isOnline) {
          debugPrint(
              '📡 OfflineSyncManager: Conexão restaurada, processando pendências...');
          await processPendingData(userId);
        } else {
          debugPrint('📴 OfflineSyncManager: Conexão perdida');
        }
      },
      onError: (error) {
        debugPrint(
            '❌ OfflineSyncManager: Erro no listener de conectividade: $error');
      },
    );
  }

  /// Processar todos os dados pendentes
  ///
  /// - Imagens OCR pendentes
  /// - Ações de medicamentos pendentes
  /// CORRIGIDO: Proteção contra execução concorrente
  static Future<void> processPendingData(String userId) async {
    // Evitar processamento concorrente
    if (_isProcessing) {
      debugPrint('⚠️ OfflineSyncManager: Processamento já em andamento, ignorando...');
      return;
    }

    _isProcessing = true;
    try {
      debugPrint('🔄 OfflineSyncManager: Processando dados pendentes...');

      // 1. Processar imagens OCR pendentes
      final ocrProcessed = await OcrOfflineService.processPendingImages();
      if (ocrProcessed > 0) {
        debugPrint(
            '✅ OfflineSyncManager: $ocrProcessed imagens OCR processadas');
      }

      // 2. Sincronizar ações de medicamentos pendentes com retry logic
      try {
        await processPendingActionsWithRetry(userId);
      } catch (e) {
        debugPrint('⚠️ OfflineSyncManager: Erro ao sincronizar ações: $e');
      }

      // 3. Limpar imagens antigas (manutenção)
      await OcrOfflineService.cleanupOldImages();

      // 4. Limpar ações sincronizadas antigas
      await OfflineCacheService.cleanupSyncedActions();

      debugPrint('✅ OfflineSyncManager: Processamento de pendências concluído');
    } catch (e) {
      debugPrint('❌ OfflineSyncManager: Erro ao processar dados pendentes: $e');
    } finally {
      _isProcessing = false; // Sempre liberar flag, mesmo em caso de erro
    }
  }

  /// Sincronizar ações de medicamentos pendentes
  static Future<void> processPendingActionsWithRetry(String userId) async {
    try {
      final supabaseService = GetIt.I<SupabaseService>();
      final medicamentoService = MedicamentoService(supabaseService.client);
      final syncService = MedicationSyncService(medicamentoService, userId);

      // Usar o método de sincronização do MedicationSyncService
      await syncService.syncPendingActions();
      debugPrint('✅ OfflineSyncManager: Ações de medicamentos sincronizadas');
    } catch (e) {
      debugPrint('⚠️ OfflineSyncManager: Erro ao sincronizar medicamentos: $e');
    }
  }

  /// Desinicializar gerenciador
  static void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _initialized = false;
    debugPrint('🛑 OfflineSyncManager: Desinicializado');
  }
}
