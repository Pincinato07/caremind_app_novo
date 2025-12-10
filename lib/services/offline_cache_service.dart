import 'dart:convert';
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
  
  static Future<void> cacheMedicamentos(String userId, List<Medicamento> medicamentos) async {
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
      return decoded.map((item) => Medicamento.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      debugPrint('❌ Get cached medicamentos erro: $e');
      return [];
    }
  }

  // === ROTINAS CACHE ===
  
  static Future<void> cacheRotinas(String userId, List<Map<String, dynamic>> rotinas) async {
    if (!_initialized || _rotinasBoxInstance == null) return;
    
    try {
      await _rotinasBoxInstance!.put(userId, jsonEncode(rotinas));
      await _updateCacheTimestamp(userId, 'rotinas');
      debugPrint('✅ Cache: ${rotinas.length} rotinas salvas');
    } catch (e) {
      debugPrint('❌ Cache rotinas erro: $e');
    }
  }
  
  static Future<List<Map<String, dynamic>>> getCachedRotinas(String userId) async {
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
  
  static Future<void> cacheCompromissos(String userId, List<Map<String, dynamic>> compromissos) async {
    if (!_initialized || _compromissosBoxInstance == null) return;
    
    try {
      await _compromissosBoxInstance!.put(userId, jsonEncode(compromissos));
      await _updateCacheTimestamp(userId, 'compromissos');
      debugPrint('✅ Cache: ${compromissos.length} compromissos salvos');
    } catch (e) {
      debugPrint('❌ Cache compromissos erro: $e');
    }
  }
  
  static Future<List<Map<String, dynamic>>> getCachedCompromissos(String userId) async {
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
  
  static Future<void> addPendingAction(Map<String, dynamic> action) async {
    if (!_initialized || _pendingActionsBoxInstance == null) return;
    
    try {
      final existing = _pendingActionsBoxInstance!.get('actions');
      List<dynamic> actions = [];
      
      if (existing != null) {
        actions = List.from(jsonDecode(existing));
      }
      
      action['timestamp'] = DateTime.now().toIso8601String();
      actions.add(action);
      
      await _pendingActionsBoxInstance!.put('actions', jsonEncode(actions));
      debugPrint('✅ Ação pendente adicionada: ${action['type']}');
    } catch (e) {
      debugPrint('❌ Erro ao adicionar ação pendente: $e');
    }
  }
  
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
  
  static Future<void> clearPendingActions() async {
    if (!_initialized || _pendingActionsBoxInstance == null) return;
    
    try {
      await _pendingActionsBoxInstance!.delete('actions');
      debugPrint('✅ Ações pendentes limpas');
    } catch (e) {
      debugPrint('❌ Erro ao limpar ações pendentes: $e');
    }
  }

  // === CACHE META ===
  
  static Future<void> _updateCacheTimestamp(String userId, String type) async {
    if (_metaBoxInstance == null) return;
    
    try {
      await _metaBoxInstance!.put('${userId}_${type}_timestamp', DateTime.now().toIso8601String());
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
  
  static Future<bool> isCacheValid(String userId, String type, {Duration maxAge = const Duration(hours: 24)}) async {
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
