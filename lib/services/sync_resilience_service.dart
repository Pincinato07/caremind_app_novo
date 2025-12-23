import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'offline_cache_service.dart';
import 'medication_sync_service.dart';
import 'medicamento_service.dart';
import 'supabase_service.dart';
import 'package:get_it/get_it.dart';

/// Serviço de Resiliência e Monitoramento de Sincronização
///
/// Responsável por:
/// - Detectar e prevenir perda de dados
/// - Monitorar duplicidade de registros
/// - Detectar travamentos de interface
/// - Implementar retry com backoff exponencial
/// - Validar integridade dos dados após sync
class SyncResilienceService {
  static final SyncResilienceService _instance = SyncResilienceService._internal();
  factory SyncResilienceService() => _instance;
  SyncResilienceService._internal();

  final Map<String, DateTime> _lastSyncAttempt = {};
  final Map<String, int> _retryCount = {};
  final Map<String, List<Map<String, dynamic>>> _syncHistory = {};
  final Map<String, int> _consecutiveFailures = {}; // Circuit breaker
  static const int _maxRetries = 5;
  static const int _maxConsecutiveFailures = 3; // Circuit breaker threshold
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(minutes: 5);
  static const Duration _circuitBreakerTimeout = Duration(minutes: 10);

  /// Sincronizar com retry e validação de integridade
  Future<SyncResult> syncWithResilience(String userId) async {
    final syncId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final startTime = DateTime.now();

    try {
      debugPrint('🔄 SyncResilience: Iniciando sincronização $syncId');

      // Verificar conectividade
      final isOnline = await OfflineCacheService.isOnline();
      if (!isOnline) {
        return SyncResult(
          success: false,
          error: 'Offline',
          pendingCount: await _getPendingCount(),
        );
      }

      // Verificar circuit breaker
      if (_isCircuitOpen(userId)) {
        debugPrint('⚠️ SyncResilience: Circuit breaker aberto para $userId');
        return SyncResult(
          success: false,
          error: 'Circuit breaker aberto - muitas falhas consecutivas',
          pendingCount: await _getPendingCount(),
        );
      }

      // Verificar se já está sincronizando (prevenir concorrência)
      if (_isSyncing(userId)) {
        debugPrint('⚠️ SyncResilience: Sincronização já em andamento para $userId');
        return SyncResult(
          success: false,
          error: 'Sync já em andamento',
          pendingCount: await _getPendingCount(),
        );
      }

      _markSyncing(userId, true);

      // Executar sincronização com retry
      final result = await _executeSyncWithRetry(userId, syncId);

      // Validar integridade após sync
      final integrityCheck = await _validateDataIntegrity(userId);
      if (!integrityCheck.isValid) {
        debugPrint('⚠️ SyncResilience: Problemas de integridade detectados: ${integrityCheck.issues}');
      }

      // Registrar histórico
      _recordSyncHistory(userId, syncId, result, startTime, integrityCheck);

      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ SyncResilience: Erro crítico na sincronização: $e');
      debugPrint('Stack trace: $stackTrace');
      return SyncResult(
        success: false,
        error: e.toString(),
        pendingCount: await _getPendingCount(),
      );
    } finally {
      _markSyncing(userId, false);
    }
  }

  /// Executar sincronização com retry e backoff exponencial
  Future<SyncResult> _executeSyncWithRetry(String userId, String syncId) async {
    int attempt = 0;
    Duration delay = _initialRetryDelay;

    while (attempt < _maxRetries) {
      try {
        attempt++;
        _retryCount[syncId] = attempt;

        debugPrint('🔄 SyncResilience: Tentativa $attempt/$_maxRetries');

        // Executar sincronização
        final supabaseService = GetIt.I<SupabaseService>();
        final medicamentoService = MedicamentoService(supabaseService.client);
        final syncService = MedicationSyncService(medicamentoService, userId);

        // Capturar estado antes da sync
        final beforeState = await _captureState(userId);

        // Executar sync
        await syncService.syncPendingActions();

        // Capturar estado após sync
        final afterState = await _captureState(userId);

        // Verificar se houve mudanças (validação básica)
        if (beforeState.pendingCount == afterState.pendingCount &&
            beforeState.pendingCount > 0) {
          throw Exception('Sync não processou ações pendentes');
        }

        // Verificar duplicatas
        final duplicates = await checkForDuplicates(userId);
        if (duplicates.isNotEmpty) {
          debugPrint('⚠️ SyncResilience: Duplicatas detectadas: ${duplicates.length}');
        }

        // Sucesso - resetar circuit breaker
        _retryCount.remove(syncId);
        _consecutiveFailures.remove(userId);
        
        final syncedCount = beforeState.pendingCount - afterState.pendingCount;
        debugPrint('✅ SyncResilience: Sincronização bem-sucedida - $syncedCount ações sincronizadas');
        
        return SyncResult(
          success: true,
          syncedCount: syncedCount,
          pendingCount: afterState.pendingCount,
          duplicates: duplicates,
        );
      } catch (e) {
        debugPrint('❌ SyncResilience: Erro na tentativa $attempt: $e');

        if (attempt >= _maxRetries) {
          // Incrementar falhas consecutivas para circuit breaker
          _consecutiveFailures[userId] = (_consecutiveFailures[userId] ?? 0) + 1;
          _lastSyncAttempt[userId] = DateTime.now(); // Registrar tentativa para circuit breaker
          
          debugPrint('❌ SyncResilience: Falhou após $_maxRetries tentativas. Falhas consecutivas: ${_consecutiveFailures[userId]}');
          
          return SyncResult(
            success: false,
            error: 'Falhou após $_maxRetries tentativas: $e',
            pendingCount: await _getPendingCount(),
          );
        }

        // Backoff exponencial
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(
            _initialRetryDelay.inMilliseconds,
            _maxRetryDelay.inMilliseconds,
          ),
        );
      }
    }

    return SyncResult(
      success: false,
      error: 'Máximo de tentativas atingido',
      pendingCount: await _getPendingCount(),
    );
  }

  /// Validar integridade dos dados após sincronização
  Future<IntegrityCheck> _validateDataIntegrity(String userId) async {
    final issues = <String>[];

    try {
      // 0. Verificar se há muitas ações pendentes (possível problema)
      final allPendingActions = await OfflineCacheService.getPendingActions();
      if (allPendingActions.length > 100) {
        issues.add('Muitas ações pendentes (${allPendingActions.length}) - possível problema de sincronização');
      }
      // 1. Verificar se há ações pendentes órfãs (marcadas como sync mas ainda pendentes)
      final allPending = await OfflineCacheService.getPendingActions();
      final syncedButPending = allPending.where((a) {
        return a['synced'] == true && a['action_id'] != null;
      }).toList();

      if (syncedButPending.isNotEmpty) {
        issues.add('${syncedButPending.length} ações marcadas como sync mas ainda pendentes');
      }

      // 2. Verificar ações muito antigas (possível perda de dados)
      final now = DateTime.now();
      final oldActions = allPending.where((a) {
        final timestamp = a['created_at'] as String?;
        if (timestamp == null) return false;
        final age = now.difference(DateTime.parse(timestamp));
        return age.inDays > 7; // Mais de 7 dias
      }).toList();

      if (oldActions.isNotEmpty) {
        issues.add('${oldActions.length} ações pendentes há mais de 7 dias');
      }

      // 3. Verificar ações com muitos retries (possível problema)
      final highRetryActions = allPending.where((a) {
        final retryCount = a['retry_count'] as int? ?? 0;
        return retryCount > 10;
      }).toList();

      if (highRetryActions.isNotEmpty) {
        issues.add('${highRetryActions.length} ações com mais de 10 tentativas');
      }

      // 4. Verificar cache vs pending (inconsistência)
      final cached = await OfflineCacheService.getCachedMedicamentos(userId);
      final pending = await OfflineCacheService.getUnsyncedActions();
      final addActions = pending.where((a) => a['type'] == 'add_medicamento').length;

      // Se há muitas ações de adicionar mas cache não reflete, pode haver problema
      if (addActions > 0 && cached.isEmpty) {
        issues.add('Ações de adicionar pendentes mas cache vazio');
      }

      // 5. Verificar ações com dados inválidos
      final invalidActions = pending.where((a) {
        final type = a['type'] as String?;
        if (type == 'add_medicamento') {
          final data = a['data'] as Map<String, dynamic>?;
          return data == null || data['nome'] == null || data['perfil_id'] == null;
        } else if (type == 'toggle_concluido') {
          return a['medicamento_id'] == null || a['data_prevista'] == null;
        }
        return false;
      }).length;

      if (invalidActions > 0) {
        issues.add('$invalidActions ações com dados inválidos ou incompletos');
      }

      // 6. Verificar ações duplicadas por hash
      final actionHashes = <String>{};
      final duplicateHashes = <String>{};
      for (final action in pending) {
        final hash = action['action_hash'] as String?;
        if (hash != null) {
          if (actionHashes.contains(hash)) {
            duplicateHashes.add(hash);
          } else {
            actionHashes.add(hash);
          }
        }
      }

      if (duplicateHashes.isNotEmpty) {
        issues.add('${duplicateHashes.length} ações com hash duplicado detectadas');
      }
    } catch (e) {
      issues.add('Erro ao validar integridade: $e');
    }

    return IntegrityCheck(
      isValid: issues.isEmpty,
      issues: issues,
    );
  }

  /// Verificar duplicatas de medicamentos
  Future<List<String>> checkForDuplicates(String userId) async {
    try {
      final supabaseService = GetIt.I<SupabaseService>();
      final medicamentoService = MedicamentoService(supabaseService.client);
      final result = await medicamentoService.getMedicamentos(userId);

      return result.when(
        success: (medicamentos) {
          final duplicates = <String>[];
          final seen = <String>{};

          for (final med in medicamentos) {
            final key = '${med.nome.toLowerCase()}_${med.dosagem}_${med.frequencia}';
            if (seen.contains(key)) {
              duplicates.add('${med.nome} (ID: ${med.id})');
            } else {
              seen.add(key);
            }
          }

          return duplicates;
        },
        failure: (_) => [],
      );
    } catch (e) {
      debugPrint('⚠️ SyncResilience: Erro ao verificar duplicatas: $e');
      return [];
    }
  }

  /// Capturar estado atual para comparação
  Future<SyncState> _captureState(String userId) async {
    final pending = await OfflineCacheService.getUnsyncedActions();
    final cached = await OfflineCacheService.getCachedMedicamentos(userId);

    return SyncState(
      pendingCount: pending.length,
      cachedCount: cached.length,
      timestamp: DateTime.now(),
    );
  }

  /// Obter contagem de pendentes
  Future<int> _getPendingCount() async {
    final pending = await OfflineCacheService.getUnsyncedActions();
    return pending.length;
  }

  /// Verificar se está sincronizando
  bool _isSyncing(String userId) {
    return _lastSyncAttempt.containsKey(userId) &&
        DateTime.now().difference(_lastSyncAttempt[userId]!) < const Duration(minutes: 5);
  }

  /// Verificar se circuit breaker está aberto
  bool _isCircuitOpen(String userId) {
    final failures = _consecutiveFailures[userId] ?? 0;
    if (failures < _maxConsecutiveFailures) return false;

    // Verificar se já passou tempo suficiente para tentar novamente
    final lastAttempt = _lastSyncAttempt[userId];
    if (lastAttempt == null) return false;

    final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
    if (timeSinceLastAttempt > _circuitBreakerTimeout) {
      // Resetar circuit breaker após timeout
      _consecutiveFailures.remove(userId);
      debugPrint('🔄 SyncResilience: Circuit breaker resetado para $userId após timeout');
      return false;
    }

    return true;
  }

  /// Marcar como sincronizando
  void _markSyncing(String userId, bool syncing) {
    if (syncing) {
      _lastSyncAttempt[userId] = DateTime.now();
    } else {
      _lastSyncAttempt.remove(userId);
    }
  }

  /// Registrar histórico de sincronização
  void _recordSyncHistory(
    String userId,
    String syncId,
    SyncResult result,
    DateTime startTime,
    IntegrityCheck integrity,
  ) {
    if (!_syncHistory.containsKey(userId)) {
      _syncHistory[userId] = [];
    }

    _syncHistory[userId]!.add({
      'sync_id': syncId,
      'timestamp': startTime.toIso8601String(),
      'duration_ms': DateTime.now().difference(startTime).inMilliseconds,
      'success': result.success,
      'synced_count': result.syncedCount,
      'pending_count': result.pendingCount,
      'duplicates': result.duplicates.length,
      'integrity_issues': integrity.issues.length,
      'retry_count': _retryCount[syncId] ?? 1,
    });

    // Manter apenas últimos 50 registros
    if (_syncHistory[userId]!.length > 50) {
      _syncHistory[userId]!.removeAt(0);
    }
  }

  /// Obter histórico de sincronização
  List<Map<String, dynamic>> getSyncHistory(String userId) {
    return _syncHistory[userId] ?? [];
  }

  /// Obter estatísticas de sincronização
  Future<SyncStats> getSyncStats(String userId) async {
    final history = getSyncHistory(userId);
    final pending = await OfflineCacheService.getUnsyncedActions();
    final duplicates = await checkForDuplicates(userId);

    int successCount = 0;
    int failureCount = 0;
    int totalRetries = 0;
    final durations = <int>[];

    for (final record in history) {
      if (record['success'] == true) {
        successCount++;
      } else {
        failureCount++;
      }
      totalRetries += record['retry_count'] as int? ?? 0;
      
      final duration = record['duration_ms'] as int?;
      if (duration != null) {
        durations.add(duration);
      }
    }

    // Calcular estatísticas de duração
    double? averageDuration;
    int? maxDuration;
    int? minDuration;
    
    if (durations.isNotEmpty) {
      averageDuration = durations.reduce((a, b) => a + b) / durations.length;
      maxDuration = durations.reduce((a, b) => a > b ? a : b);
      minDuration = durations.reduce((a, b) => a < b ? a : b);
    }

    return SyncStats(
      totalSyncs: history.length,
      successCount: successCount,
      failureCount: failureCount,
      pendingCount: pending.length,
      duplicateCount: duplicates.length,
      totalRetries: totalRetries,
      lastSync: history.isNotEmpty
          ? DateTime.parse(history.last['timestamp'] as String)
          : null,
      averageSyncDuration: averageDuration,
      maxSyncDuration: maxDuration,
      minSyncDuration: minDuration,
    );
  }

  /// Limpar dados de sincronização antigos
  Future<void> cleanup() async {
    // Limpar tentativas antigas
    final now = DateTime.now();
    _lastSyncAttempt.removeWhere((key, value) {
      return now.difference(value) > const Duration(hours: 24);
    });

    // Limpar histórico antigo (manter apenas últimos 7 dias)
    for (final userId in _syncHistory.keys) {
      _syncHistory[userId]!.removeWhere((record) {
        final timestamp = DateTime.parse(record['timestamp'] as String);
        return now.difference(timestamp) > const Duration(days: 7);
      });
    }

    // Limpar circuit breaker para usuários que não tentaram sincronizar há muito tempo
    _consecutiveFailures.removeWhere((key, value) {
      final lastAttempt = _lastSyncAttempt[key];
      if (lastAttempt == null) return true;
      return now.difference(lastAttempt) > const Duration(hours: 24);
    });
  }

  /// Obter status do circuit breaker
  Map<String, dynamic> getCircuitBreakerStatus(String userId) {
    final failures = _consecutiveFailures[userId] ?? 0;
    final isOpen = _isCircuitOpen(userId);
    final lastAttempt = _lastSyncAttempt[userId];

    return {
      'is_open': isOpen,
      'consecutive_failures': failures,
      'last_attempt': lastAttempt?.toIso8601String(),
      'time_until_reset': isOpen && lastAttempt != null
          ? _circuitBreakerTimeout.inSeconds - 
            DateTime.now().difference(lastAttempt).inSeconds
          : 0,
    };
  }

  /// Forçar reset do circuit breaker (para testes ou recuperação manual)
  void resetCircuitBreaker(String userId) {
    _consecutiveFailures.remove(userId);
    debugPrint('🔄 SyncResilience: Circuit breaker resetado manualmente para $userId');
  }
}

/// Resultado de sincronização
class SyncResult {
  final bool success;
  final String? error;
  final int syncedCount;
  final int pendingCount;
  final List<String> duplicates;

  SyncResult({
    required this.success,
    this.error,
    this.syncedCount = 0,
    this.pendingCount = 0,
    this.duplicates = const [],
  });
}

/// Estado de sincronização
class SyncState {
  final int pendingCount;
  final int cachedCount;
  final DateTime timestamp;

  SyncState({
    required this.pendingCount,
    required this.cachedCount,
    required this.timestamp,
  });
}

/// Verificação de integridade
class IntegrityCheck {
  final bool isValid;
  final List<String> issues;

  IntegrityCheck({
    required this.isValid,
    required this.issues,
  });
}

/// Estatísticas de sincronização
class SyncStats {
  final int totalSyncs;
  final int successCount;
  final int failureCount;
  final int pendingCount;
  final int duplicateCount;
  final int totalRetries;
  final DateTime? lastSync;
  final double? averageSyncDuration;
  final int? maxSyncDuration;
  final int? minSyncDuration;

  SyncStats({
    required this.totalSyncs,
    required this.successCount,
    required this.failureCount,
    required this.pendingCount,
    required this.duplicateCount,
    required this.totalRetries,
    this.lastSync,
    this.averageSyncDuration,
    this.maxSyncDuration,
    this.minSyncDuration,
  });

  double get successRate {
    if (totalSyncs == 0) return 0.0;
    return successCount / totalSyncs;
  }

  bool get hasIssues {
    return duplicateCount > 0 || 
           pendingCount > 50 || 
           successRate < 0.8 ||
           (averageSyncDuration != null && averageSyncDuration! > 30000); // > 30s
  }
}

