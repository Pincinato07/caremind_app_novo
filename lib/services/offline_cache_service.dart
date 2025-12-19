import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/medicamento.dart';

class OfflineCacheService {
  static const String _medicamentosBox = 'medicamentos_cache';
  static const String _rotinasBox = 'rotinas_cache';
  static const String _compromissosBox = 'compromissos_cache';
  static const String _pendingActionsBox = 'pending_actions';
  static const String _metaBox = 'cache_meta';

  static bool _initialized = false;
  static Box? _medicamentosBoxInstance;
  static Box? _rotinasBoxInstance;
  static Box? _compromissosBoxInstance;
  static Box? _pendingActionsBoxInstance;
  static Box? _metaBoxInstance;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();

      _medicamentosBoxInstance = await Hive.openBox(_medicamentosBox);
      _rotinasBoxInstance = await Hive.openBox(_rotinasBox);
      _compromissosBoxInstance = await Hive.openBox(_compromissosBox);
      _pendingActionsBoxInstance = await Hive.openBox(_pendingActionsBox);
      _metaBoxInstance = await Hive.openBox(_metaBox);

      _initialized = true;
      debugPrint('✅ OfflineCacheService: Inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ OfflineCacheService: Erro ao inicializar: $e');
    }
  }

  static Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.first != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  static Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map((result) {
      return result.first != ConnectivityResult.none;
    });
  }

  // === MEDICAMENTOS CACHE ===

  static Future<void> cacheMedicamentos(
      String userId, List<Medicamento> medicamentos) async {
    if (!_initialized || _medicamentosBoxInstance == null) return;

    try {
      final data = medicamentos.map((m) => m.toMap()).toList();
      await _medicamentosBoxInstance!.put(userId, jsonEncode(data));
      await _updateCacheTimestamp(userId, 'medicamentos');
      debugPrint('✅ Cache: ${medicamentos.length} medicamentos salvos');
    } catch (e) {
      debugPrint('❌ Cache medicamentos erro: $e');
    }
  }

  static Future<List<Medicamento>> getCachedMedicamentos(String userId) async {
    if (!_initialized || _medicamentosBoxInstance == null) return [];

    try {
      final data = _medicamentosBoxInstance!.get(userId);
      if (data == null) return [];

      final List<dynamic> decoded = jsonDecode(data);
      return decoded
          .map((item) => Medicamento.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('❌ Get cached medicamentos erro: $e');
      return [];
    }
  }

  // === ROTINAS CACHE ===

  static Future<void> cacheRotinas(
      String userId, List<Map<String, dynamic>> rotinas) async {
    if (!_initialized || _rotinasBoxInstance == null) return;

    try {
      await _rotinasBoxInstance!.put(userId, jsonEncode(rotinas));
      await _updateCacheTimestamp(userId, 'rotinas');
      debugPrint('✅ Cache: ${rotinas.length} rotinas salvas');
    } catch (e) {
      debugPrint('❌ Cache rotinas erro: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getCachedRotinas(
      String userId) async {
    if (!_initialized || _rotinasBoxInstance == null) return [];

    try {
      final data = _rotinasBoxInstance!.get(userId);
      if (data == null) return [];

      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('❌ Get cached rotinas erro: $e');
      return [];
    }
  }

  // === COMPROMISSOS CACHE ===

  static Future<void> cacheCompromissos(
      String userId, List<Map<String, dynamic>> compromissos) async {
    if (!_initialized || _compromissosBoxInstance == null) return;

    try {
      await _compromissosBoxInstance!.put(userId, jsonEncode(compromissos));
      await _updateCacheTimestamp(userId, 'compromissos');
      debugPrint('✅ Cache: ${compromissos.length} compromissos salvos');
    } catch (e) {
      debugPrint('❌ Cache compromissos erro: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getCachedCompromissos(
      String userId) async {
    if (!_initialized || _compromissosBoxInstance == null) return [];

    try {
      final data = _compromissosBoxInstance!.get(userId);
      if (data == null) return [];

      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('❌ Get cached compromissos erro: $e');
      return [];
    }
  }

  // === PENDING ACTIONS (para sync quando voltar online) ===

  /// Gera hash único para uma ação offline baseado no conteúdo
  ///
  /// O hash é gerado a partir do tipo de ação e dos dados principais,
  /// garantindo que ações idênticas tenham o mesmo hash e sejam detectadas como duplicatas.
  static String generateActionHash(Map<String, dynamic> action) {
    try {
      // Criar uma representação estável da ação para hash
      final hashData = {
        'type': action['type'] ?? '',
        'data': action['data'] ?? action,
        // Incluir campos relevantes que identificam unicamente a ação
        if (action.containsKey('medicamento_id'))
          'medicamento_id': action['medicamento_id'],
        if (action.containsKey('perfil_id')) 'perfil_id': action['perfil_id'],
        if (action.containsKey('timestamp')) 'timestamp': action['timestamp'],
      };

      final jsonString = jsonEncode(hashData);
      final bytes = utf8.encode(jsonString);
      final digest = sha256.convert(bytes);

      return digest.toString();
    } catch (e) {
      debugPrint('❌ Erro ao gerar hash de ação: $e');
      // Fallback: usar timestamp + tipo como hash
      return '${action['type']}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Adiciona uma ação pendente com hash único para controle de idempotência
  ///
  /// [action] - Ação a ser adicionada
  ///
  /// A função:
  /// - Gera um hash único baseado no conteúdo da ação
  /// - Verifica se já existe ação com mesmo hash (evita duplicatas)
  /// - Adiciona metadados padrão (timestamp, retry_count, etc.)
  static Future<void> addPendingAction(Map<String, dynamic> action) async {
    if (!_initialized || _pendingActionsBoxInstance == null) return;

    try {
      // Gerar hash único para a ação
      final actionHash = generateActionHash(action);

      // Verificar se já existe ação com mesmo hash (prevenir duplicatas)
      final existing = _pendingActionsBoxInstance!.get('actions');
      List<dynamic> actions = [];

      if (existing != null) {
        actions = List.from(jsonDecode(existing));
      }

      // Verificar duplicatas por hash
      final exists = actions.any((a) {
        final existingHash =
            (a as Map<String, dynamic>)['action_hash'] as String?;
        return existingHash == actionHash;
      });

      if (exists) {
        debugPrint(
            '⚠️ Ação com hash $actionHash já existe, ignorando duplicata');
        return;
      }

      // Adicionar hash e metadados padrão
      action['action_hash'] = actionHash;
      action['action_id'] = action['action_id'] ??
          '${action['type']}_${DateTime.now().millisecondsSinceEpoch}';

      if (action['timestamp'] == null) {
        action['timestamp'] = DateTime.now().toIso8601String();
      }
      if (action['synced'] == null) {
        action['synced'] = false;
      }
      if (action['retry_count'] == null) {
        action['retry_count'] = 0;
      }
      if (action['created_at'] == null) {
        action['created_at'] = DateTime.now().toIso8601String();
      }

      actions.add(action);

      await _pendingActionsBoxInstance!.put('actions', jsonEncode(actions));
      debugPrint(
          '✅ Ação pendente adicionada: ${action['type']} (Hash: ${actionHash.substring(0, 8)}...)');
    } catch (e) {
      debugPrint('❌ Erro ao adicionar ação pendente: $e');
    }
  }

  /// Obtém todas as ações pendentes (não sincronizadas)
  static Future<List<Map<String, dynamic>>> getPendingActions() async {
    if (!_initialized || _pendingActionsBoxInstance == null) return [];

    try {
      final data = _pendingActionsBoxInstance!.get('actions');
      if (data == null) return [];

      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('❌ Erro ao obter ações pendentes: $e');
      return [];
    }
  }

  /// Obtém apenas ações pendentes não sincronizadas
  static Future<List<Map<String, dynamic>>> getUnsyncedActions() async {
    final all = await getPendingActions();
    return all.where((a) => a['synced'] != true).toList();
  }

  /// Marca uma ação como sincronizada
  static Future<void> markActionAsSynced(String actionId) async {
    if (!_initialized || _pendingActionsBoxInstance == null) return;

    try {
      final all = await getPendingActions();
      final updated = all.map((action) {
        if (action['action_id'] == actionId) {
          return {
            ...action,
            'synced': true,
            'synced_at': DateTime.now().toIso8601String(),
          };
        }
        return action;
      }).toList();

      await _pendingActionsBoxInstance!.put('actions', jsonEncode(updated));
      debugPrint('✅ Ação $actionId marcada como sincronizada');
    } catch (e) {
      debugPrint('❌ Erro ao marcar ação como sincronizada: $e');
    }
  }

  /// Substitui todas as ações pendentes (usado para atualização em lote)
  static Future<void> replacePendingActions(
      List<Map<String, dynamic>> newActions) async {
    if (!_initialized || _pendingActionsBoxInstance == null) return;

    try {
      // Manter outras ações que não são OCR
      final all = await getPendingActions();
      final otherActions = all.where((a) => a['type'] != 'ocr_upload').toList();

      // Combinar com novas ações
      final combined = [...otherActions, ...newActions];

      await _pendingActionsBoxInstance!.put('actions', jsonEncode(combined));
      debugPrint('✅ Ações pendentes atualizadas: ${combined.length} ações');
    } catch (e) {
      debugPrint('❌ Erro ao substituir ações pendentes: $e');
    }
  }

  /// Remove ações sincronizadas antigas (mais de 24h)
  static Future<void> cleanupSyncedActions(
      {Duration maxAge = const Duration(hours: 24)}) async {
    if (!_initialized || _pendingActionsBoxInstance == null) return;

    try {
      final all = await getPendingActions();
      final now = DateTime.now();

      final filtered = all.where((action) {
        if (action['synced'] != true) return true; // Manter não sincronizadas

        final syncedAt = action['synced_at'] as String?;
        if (syncedAt == null) return true; // Manter se não tiver timestamp

        final syncedTime = DateTime.parse(syncedAt);
        final age = now.difference(syncedTime);

        return age < maxAge; // Remover apenas se for muito antiga
      }).toList();

      if (filtered.length < all.length) {
        await _pendingActionsBoxInstance!.put('actions', jsonEncode(filtered));
        final removed = all.length - filtered.length;
        debugPrint(
            '🧹 Limpeza: $removed ações sincronizadas antigas removidas');
      }
    } catch (e) {
      debugPrint('❌ Erro ao limpar ações sincronizadas: $e');
    }
  }

  /// Limpa todas as ações pendentes
  static Future<void> clearPendingActions() async {
    if (!_initialized || _pendingActionsBoxInstance == null) return;

    try {
      await _pendingActionsBoxInstance!.delete('actions');
      debugPrint('✅ Ações pendentes limpas');
    } catch (e) {
      debugPrint('❌ Erro ao limpar ações pendentes: $e');
    }
  }

  /// Conta ações pendentes por tipo
  static Future<Map<String, int>> getPendingActionsCount() async {
    final all = await getUnsyncedActions();
    final counts = <String, int>{};

    for (final action in all) {
      final type = action['type'] as String? ?? 'unknown';
      counts[type] = (counts[type] ?? 0) + 1;
    }

    return counts;
  }

  // === CACHE META ===

  static Future<void> _updateCacheTimestamp(String userId, String type) async {
    if (_metaBoxInstance == null) return;

    try {
      await _metaBoxInstance!
          .put('${userId}_${type}_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ Erro ao atualizar timestamp: $e');
    }
  }

  static Future<DateTime?> getCacheTimestamp(String userId, String type) async {
    if (!_initialized || _metaBoxInstance == null) return null;

    try {
      final timestamp = _metaBoxInstance!.get('${userId}_${type}_timestamp');
      if (timestamp == null) return null;
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> isCacheValid(String userId, String type,
      {Duration maxAge = const Duration(hours: 24)}) async {
    final timestamp = await getCacheTimestamp(userId, type);
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < maxAge;
  }

  // === CLEAR CACHE ===

  static Future<void> clearUserCache(String userId) async {
    if (!_initialized) return;

    try {
      await _medicamentosBoxInstance?.delete(userId);
      await _rotinasBoxInstance?.delete(userId);
      await _compromissosBoxInstance?.delete(userId);
      await _metaBoxInstance?.delete('${userId}_medicamentos_timestamp');
      await _metaBoxInstance?.delete('${userId}_rotinas_timestamp');
      await _metaBoxInstance?.delete('${userId}_compromissos_timestamp');
      debugPrint('✅ Cache do usuário $userId limpo');
    } catch (e) {
      debugPrint('❌ Erro ao limpar cache: $e');
    }
  }

  static Future<void> clearAllCache() async {
    if (!_initialized) return;

    try {
      await _medicamentosBoxInstance?.clear();
      await _rotinasBoxInstance?.clear();
      await _compromissosBoxInstance?.clear();
      await _pendingActionsBoxInstance?.clear();
      await _metaBoxInstance?.clear();
      debugPrint('✅ Todo cache limpo');
    } catch (e) {
      debugPrint('❌ Erro ao limpar todo cache: $e');
    }
  }
}
