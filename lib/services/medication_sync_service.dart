import 'package:flutter/foundation.dart';
import '../models/medicamento.dart';
import 'offline_cache_service.dart';
import 'medicamento_service.dart';
import 'notification_service.dart';

/// Serviço de Sincronização de Medicamentos com Estratégia Cache-First
/// 
/// **Blindagem Offline (Saúde não espera o Wi-Fi)**
/// 
/// Implementa a estratégia "Cache-First" para garantir que:
/// - Os medicamentos SEMPRE aparecem na tela, mesmo sem internet
/// - Os alarmes SEMPRE tocam, mesmo sem internet
/// - A sincronização acontece automaticamente quando a conexão volta
/// 
/// **Fluxo de Operação:**
/// 
/// 1. **Ao abrir o app COM internet:**
///    - Busca medicamentos do Supabase
///    - Salva no cache local (Hive)
///    - Agenda notificações locais no sistema nativo
/// 
/// 2. **Ao abrir o app SEM internet:**
///    - Lê medicamentos do cache local (Hive)
///    - Mostra na tela normalmente
///    - Notificações já agendadas continuam funcionando
/// 
/// 3. **Ao voltar online:**
///    - Sincroniza ações pendentes (medicamentos marcados como tomados)
///    - Atualiza cache com dados mais recentes
class MedicationSyncService {
  final MedicamentoService _medicamentoService;
  final String _userId;
  
  MedicationSyncService(this._medicamentoService, this._userId);

  /// Buscar medicamentos com estratégia cache-first
  /// 
  /// **Prioridade:**
  /// 1. Tenta buscar do Supabase (se online)
  /// 2. Se offline ou erro, usa cache local
  /// 3. Sempre agenda notificações locais
  /// 
  /// **Garantia:** SEMPRE retorna dados, mesmo offline
  Future<List<Medicamento>> getMedicamentosWithCache() async {
    final isOnline = await OfflineCacheService.isOnline();
    
    if (isOnline) {
      try {
        // Buscar do Supabase (fonte de verdade)
        final medicamentos = await _medicamentoService.getMedicamentos(_userId);
        
        // Salvar no cache para uso offline
        await OfflineCacheService.cacheMedicamentos(_userId, medicamentos);
        
        // Agendar notificações locais para TODOS os medicamentos
        await _scheduleAllNotifications(medicamentos);
        
        debugPrint('✅ MedicationSync: ${medicamentos.length} medicamentos sincronizados (online)');
        return medicamentos;
      } catch (e) {
        debugPrint('⚠️ MedicationSync: Erro ao buscar online, usando cache: $e');
        // Fallback para cache
        return await _getCachedMedicamentos();
      }
    } else {
      // Offline: usar cache
      debugPrint('📴 MedicationSync: Offline, usando cache local');
      return await _getCachedMedicamentos();
    }
  }

  /// Buscar medicamentos do cache local
  Future<List<Medicamento>> _getCachedMedicamentos() async {
    final cached = await OfflineCacheService.getCachedMedicamentos(_userId);
    
    if (cached.isEmpty) {
      debugPrint('⚠️ MedicationSync: Cache vazio, nenhum medicamento salvo');
    } else {
      debugPrint('✅ MedicationSync: ${cached.length} medicamentos do cache');
    }
    
    return cached;
  }

  /// Agendar notificações locais para todos os medicamentos
  /// 
  /// **Crítico:** Notificações são agendadas no sistema nativo (Android/iOS)
  /// e continuam funcionando MESMO se:
  /// - O app for fechado
  /// - O Wi-Fi cair
  /// - O dispositivo reiniciar (com RECEIVE_BOOT_COMPLETED)
  Future<void> _scheduleAllNotifications(List<Medicamento> medicamentos) async {
    for (final medicamento in medicamentos) {
      try {
        await NotificationService.scheduleMedicationReminders(medicamento);
      } catch (e) {
        debugPrint('⚠️ MedicationSync: Erro ao agendar notificação para ${medicamento.nome}: $e');
        // Continua com os outros medicamentos
      }
    }
    debugPrint('✅ MedicationSync: Notificações agendadas para ${medicamentos.length} medicamentos');
  }

  /// Adicionar medicamento com suporte offline
  /// 
  /// **Comportamento:**
  /// - Se online: salva no Supabase + cache + agenda notificação
  /// - Se offline: salva no cache + adiciona ação pendente + agenda notificação
  Future<Medicamento?> addMedicamentoWithCache(Medicamento medicamento) async {
    final isOnline = await OfflineCacheService.isOnline();
    
    if (isOnline) {
      try {
        // Salvar no Supabase
        final saved = await _medicamentoService.addMedicamento(medicamento);
        
        // Atualizar cache local
        final allMedicamentos = await _medicamentoService.getMedicamentos(_userId);
        await OfflineCacheService.cacheMedicamentos(_userId, allMedicamentos);
        
        // Notificação já é agendada automaticamente pelo MedicamentoService
        debugPrint('✅ MedicationSync: Medicamento adicionado (online)');
        return saved;
      } catch (e) {
        debugPrint('❌ MedicationSync: Erro ao adicionar online: $e');
        return null;
      }
    } else {
      // Offline: salvar localmente e adicionar ação pendente
      debugPrint('📴 MedicationSync: Offline, salvando ação pendente');
      
      // Adicionar ação pendente para sincronizar depois
      await OfflineCacheService.addPendingAction({
        'type': 'add_medicamento',
        'data': medicamento.toMap(),
      });
      
      // Atualizar cache local (sem ID real ainda)
      final cached = await OfflineCacheService.getCachedMedicamentos(_userId);
      cached.add(medicamento);
      await OfflineCacheService.cacheMedicamentos(_userId, cached);
      
      // Agendar notificação local mesmo offline
      // Nota: Usará ID temporário até sincronizar
      try {
        await NotificationService.scheduleMedicationReminders(medicamento);
      } catch (e) {
        debugPrint('⚠️ MedicationSync: Erro ao agendar notificação offline: $e');
      }
      
      return medicamento;
    }
  }

  /// Marcar medicamento como tomado com suporte offline
  /// 
  /// **Comportamento:**
  /// - Se online: atualiza no Supabase + cache
  /// - Se offline: atualiza cache + adiciona ação pendente
  Future<void> toggleMedicamentoConcluido(
    int medicamentoId,
    bool concluido,
    DateTime dataPrevista,
  ) async {
    final isOnline = await OfflineCacheService.isOnline();
    
    if (isOnline) {
      try {
        // Atualizar no Supabase
        await _medicamentoService.toggleConcluido(
          medicamentoId,
          concluido,
          dataPrevista,
        );
        
        // Atualizar cache
        final allMedicamentos = await _medicamentoService.getMedicamentos(_userId);
        await OfflineCacheService.cacheMedicamentos(_userId, allMedicamentos);
        
        debugPrint('✅ MedicationSync: Status atualizado (online)');
      } catch (e) {
        debugPrint('❌ MedicationSync: Erro ao atualizar online: $e');
      }
    } else {
      // Offline: adicionar ação pendente
      debugPrint('📴 MedicationSync: Offline, salvando ação pendente');
      
      await OfflineCacheService.addPendingAction({
        'type': 'toggle_concluido',
        'medicamento_id': medicamentoId,
        'concluido': concluido,
        'data_prevista': dataPrevista.toIso8601String(),
      });
      
      // Atualizar cache local (otimistic update)
      final cached = await OfflineCacheService.getCachedMedicamentos(_userId);
      final index = cached.indexWhere((m) => m.id == medicamentoId);
      if (index != -1 && concluido) {
        // Decrementar quantidade localmente
        final updated = cached[index].copyWith(
          quantidade: (cached[index].quantidade ?? 0) > 0 
            ? (cached[index].quantidade ?? 0) - 1 
            : 0,
        );
        cached[index] = updated;
        await OfflineCacheService.cacheMedicamentos(_userId, cached);
      }
    }
  }

  /// Sincronizar ações pendentes quando voltar online
  /// 
  /// Chamado automaticamente quando detecta que voltou online
  Future<void> syncPendingActions() async {
    final isOnline = await OfflineCacheService.isOnline();
    if (!isOnline) {
      debugPrint('📴 MedicationSync: Ainda offline, sync cancelado');
      return;
    }

    final pending = await OfflineCacheService.getPendingActions();
    if (pending.isEmpty) {
      debugPrint('✅ MedicationSync: Nenhuma ação pendente');
      return;
    }

    debugPrint('🔄 MedicationSync: Sincronizando ${pending.length} ações pendentes');

    int synced = 0;
    int failed = 0;

    for (final action in pending) {
      try {
        final type = action['type'] as String;

        switch (type) {
          case 'add_medicamento':
            final data = action['data'] as Map<String, dynamic>;
            await _medicamentoService.addMedicamento(
              Medicamento.fromMap(data),
            );
            synced++;
            break;

          case 'toggle_concluido':
            await _medicamentoService.toggleConcluido(
              action['medicamento_id'] as int,
              action['concluido'] as bool,
              DateTime.parse(action['data_prevista'] as String),
            );
            synced++;
            break;

          default:
            debugPrint('⚠️ MedicationSync: Tipo de ação desconhecido: $type');
            failed++;
        }
      } catch (e) {
        debugPrint('❌ MedicationSync: Erro ao sincronizar ação: $e');
        failed++;
      }
    }

    if (failed == 0) {
      // Todas as ações foram sincronizadas com sucesso
      await OfflineCacheService.clearPendingActions();
      debugPrint('✅ MedicationSync: $synced ações sincronizadas com sucesso');
    } else {
      debugPrint('⚠️ MedicationSync: $synced sincronizadas, $failed falharam');
    }

    // Atualizar cache com dados mais recentes
    try {
      final medicamentos = await _medicamentoService.getMedicamentos(_userId);
      await OfflineCacheService.cacheMedicamentos(_userId, medicamentos);
      await _scheduleAllNotifications(medicamentos);
    } catch (e) {
      debugPrint('⚠️ MedicationSync: Erro ao atualizar cache após sync: $e');
    }
  }

  /// Iniciar listener de conectividade para sync automático
  /// 
  /// Chame isso no início do app para sincronizar automaticamente
  /// quando o usuário voltar online
  void startConnectivityListener() {
    OfflineCacheService.connectivityStream.listen((isOnline) async {
      if (isOnline) {
        debugPrint('📡 MedicationSync: Conexão restaurada, iniciando sync');
        await syncPendingActions();
      } else {
        debugPrint('📴 MedicationSync: Conexão perdida, modo offline ativado');
      }
    });
  }

  /// Forçar refresh do cache (para pull-to-refresh)
  Future<List<Medicamento>> forceRefresh() async {
    final isOnline = await OfflineCacheService.isOnline();
    
    if (!isOnline) {
      debugPrint('📴 MedicationSync: Offline, usando cache existente');
      return await _getCachedMedicamentos();
    }

    try {
      // Sync ações pendentes primeiro
      await syncPendingActions();
      
      // Buscar dados frescos
      return await getMedicamentosWithCache();
    } catch (e) {
      debugPrint('❌ MedicationSync: Erro no refresh: $e');
      return await _getCachedMedicamentos();
    }
  }

  /// Verificar idade do cache
  Future<bool> isCacheValid({Duration maxAge = const Duration(hours: 24)}) async {
    return await OfflineCacheService.isCacheValid(_userId, 'medicamentos', maxAge: maxAge);
  }
}
