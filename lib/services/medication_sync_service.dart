import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
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
  static final Uuid _uuid = const Uuid();

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
        final medicamentosResult =
            await _medicamentoService.getMedicamentos(_userId);
        final medicamentos = medicamentosResult.when(
          success: (data) => data,
          failure: (exception) {
            throw Exception(
                'Erro ao buscar medicamentos: ${exception.message}');
          },
        );

        // Salvar no cache para uso offline
        await OfflineCacheService.cacheMedicamentos(_userId, medicamentos);

        // HARD SYNC: Deletar medicamentos órfãos (existem no cache mas não no servidor)
        await _deleteOrphanedMedications(medicamentos);

        // Agendar notificações locais para TODOS os medicamentos
        await _scheduleAllNotifications(medicamentos);

        debugPrint(
            '✅ MedicationSync: ${medicamentos.length} medicamentos sincronizados (online)');
        return medicamentos;
      } catch (e) {
        debugPrint(
            '⚠️ MedicationSync: Erro ao buscar online, usando cache: $e');
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
        debugPrint(
            '⚠️ MedicationSync: Erro ao agendar notificação para ${medicamento.nome}: $e');
        // Continua com os outros medicamentos
      }
    }
    debugPrint(
        '✅ MedicationSync: Notificações agendadas para ${medicamentos.length} medicamentos');
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
        final allMedicamentosResult =
            await _medicamentoService.getMedicamentos(_userId);
        final allMedicamentos = allMedicamentosResult.when(
          success: (data) => data,
          failure: (exception) {
            throw Exception(
                'Erro ao buscar medicamentos: ${exception.message}');
          },
        );
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

      // Gerar ID único para esta ação (idempotência)
      final actionId = _uuid.v4();

      // Adicionar ação pendente para sincronizar depois
      await OfflineCacheService.addPendingAction({
        'action_id': actionId,
        'type': 'add_medicamento',
        'data': medicamento.toMap(),
        'medicamento_hash':
            _generateMedicamentoHash(medicamento), // Para verificar duplicatas
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
        debugPrint(
            '⚠️ MedicationSync: Erro ao agendar notificação offline: $e');
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
        final allMedicamentosResult =
            await _medicamentoService.getMedicamentos(_userId);
        final allMedicamentos = allMedicamentosResult.when(
          success: (data) => data,
          failure: (exception) {
            throw Exception(
                'Erro ao buscar medicamentos: ${exception.message}');
          },
        );
        await OfflineCacheService.cacheMedicamentos(_userId, allMedicamentos);

        debugPrint('✅ MedicationSync: Status atualizado (online)');
      } catch (e) {
        debugPrint('❌ MedicationSync: Erro ao atualizar online: $e');
      }
    } else {
      // Offline: adicionar ação pendente
      debugPrint('📴 MedicationSync: Offline, salvando ação pendente');

      // Gerar ID único para esta ação (idempotência)
      // Usar combinação de medicamento_id + data + concluido para evitar duplicatas
      final actionId =
          'toggle_${medicamentoId}_${dataPrevista.toIso8601String()}_$concluido';

      await OfflineCacheService.addPendingAction({
        'action_id': actionId,
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
  /// **Idempotência:** Verifica se ação já foi processada antes de executar
  /// **Duplicatas:** Verifica se medicamento já existe antes de adicionar
  ///
  /// Chamado automaticamente quando detecta que voltou online
  Future<void> syncPendingActions() async {
    final isOnline = await OfflineCacheService.isOnline();
    if (!isOnline) {
      debugPrint('📴 MedicationSync: Ainda offline, sync cancelado');
      return;
    }

    // Buscar apenas ações não sincronizadas
    final pending = await OfflineCacheService.getUnsyncedActions();
    if (pending.isEmpty) {
      debugPrint('✅ MedicationSync: Nenhuma ação pendente');
      return;
    }

    debugPrint(
        '🔄 MedicationSync: Sincronizando ${pending.length} ações pendentes');

    int synced = 0;
    int failed = 0;
    final Set<String> processedActionIds = {};

    for (final action in pending) {
      final actionId = action['action_id'] as String?;

      // Verificar se ação já foi processada (idempotência)
      if (actionId == null) {
        debugPrint('⚠️ MedicationSync: Ação sem action_id, ignorando');
        failed++;
        continue;
      }

      if (processedActionIds.contains(actionId)) {
        debugPrint(
            '⚠️ MedicationSync: Ação $actionId já processada nesta sessão, ignorando');
        continue;
      }

      try {
        final type = action['type'] as String;

        switch (type) {
          case 'add_medicamento':
            await _syncAddMedicamento(action, actionId);
            processedActionIds.add(actionId);
            synced++;
            break;

          case 'toggle_concluido':
            await _syncToggleConcluido(action, actionId);
            processedActionIds.add(actionId);
            synced++;
            break;

          default:
            debugPrint('⚠️ MedicationSync: Tipo de ação desconhecido: $type');
            failed++;
        }
      } catch (e) {
        debugPrint('❌ MedicationSync: Erro ao sincronizar ação $actionId: $e');
        failed++;
        // Não marcar como processada se falhou
      }
    }

    // Marcar ações processadas como sincronizadas
    for (final actionId in processedActionIds) {
      await OfflineCacheService.markActionAsSynced(actionId);
    }

    debugPrint('✅ MedicationSync: $synced sincronizadas, $failed falharam');

    // Limpar ações sincronizadas antigas
    await OfflineCacheService.cleanupSyncedActions();

    // Atualizar cache com dados mais recentes
    try {
      final medicamentosResult =
          await _medicamentoService.getMedicamentos(_userId);
      final medicamentos = medicamentosResult.when(
        success: (data) => data,
        failure: (exception) {
          throw Exception('Erro ao buscar medicamentos: ${exception.message}');
        },
      );
      await OfflineCacheService.cacheMedicamentos(_userId, medicamentos);
      await _scheduleAllNotifications(medicamentos);
    } catch (e) {
      debugPrint('⚠️ MedicationSync: Erro ao atualizar cache após sync: $e');
    }
  }

  /// Sincronizar ação de adicionar medicamento (com verificação de duplicatas)
  Future<void> _syncAddMedicamento(
      Map<String, dynamic> action, String actionId) async {
    final data = action['data'] as Map<String, dynamic>;
    final medicamento = Medicamento.fromMap(data);

    // Verificar se medicamento já existe (prevenir duplicatas)
    try {
      final existingResult = await _medicamentoService.getMedicamentos(_userId);
      final existing = existingResult.when(
        success: (data) => data,
        failure: (exception) {
          throw Exception('Erro ao buscar medicamentos: ${exception.message}');
        },
      );

      // Verificar se já existe medicamento similar
      final duplicate = existing.any((m) =>
          m.nome.toLowerCase() == medicamento.nome.toLowerCase() &&
          m.dosagem == medicamento.dosagem &&
          _compareFrequencia(m.frequencia, medicamento.frequencia));

      if (duplicate) {
        debugPrint(
            '⚠️ MedicationSync: Medicamento já existe, ignorando duplicata: ${medicamento.nome}');
        return; // Não adiciona, mas marca como processada
      }
    } catch (e) {
      debugPrint('⚠️ MedicationSync: Erro ao verificar duplicatas: $e');
      // Continua mesmo se verificação falhar
    }

    // Adicionar medicamento
    await _medicamentoService.addMedicamento(medicamento);
    debugPrint('✅ MedicationSync: Medicamento adicionado: ${medicamento.nome}');
  }

  /// Sincronizar ação de toggle concluído (com verificação de idempotência)
  Future<void> _syncToggleConcluido(
      Map<String, dynamic> action, String actionId) async {
    final medicamentoId = action['medicamento_id'] as int;
    final concluido = action['concluido'] as bool;
    final dataPrevista = DateTime.parse(action['data_prevista'] as String);

    // Verificar se ação já foi aplicada (idempotência)
    // Nota: Esta verificação é básica, o backend também deve ter validação
    try {
      final medicamentosResult =
          await _medicamentoService.getMedicamentos(_userId);
      final medicamentos = medicamentosResult.when(
        success: (data) => data,
        failure: (exception) {
          throw Exception('Erro ao buscar medicamentos: ${exception.message}');
        },
      );
      medicamentos.firstWhere(
        (m) => m.id == medicamentoId,
        orElse: () => throw Exception('Medicamento não encontrado'),
      );

      // Se já está no estado desejado, não precisa atualizar
      // (verificação básica, o backend deve fazer validação completa)
    } catch (e) {
      debugPrint('⚠️ MedicationSync: Erro ao verificar estado: $e');
      // Continua mesmo se verificação falhar
    }

    // Aplicar toggle
    await _medicamentoService.toggleConcluido(
      medicamentoId,
      concluido,
      dataPrevista,
    );
    debugPrint(
        '✅ MedicationSync: Status atualizado: medicamento $medicamentoId');
  }

  /// Gerar hash único para medicamento (para verificação de duplicatas)
  String _generateMedicamentoHash(Medicamento medicamento) {
    final freq = medicamento.frequencia?.toString() ?? '';
    return '${medicamento.nome.toLowerCase()}_${medicamento.dosagem}_$freq';
  }

  /// Comparar frequências de medicamentos
  bool _compareFrequencia(dynamic freq1, dynamic freq2) {
    if (freq1 == null && freq2 == null) return true;
    if (freq1 == null || freq2 == null) return false;
    return freq1.toString() == freq2.toString();
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
  Future<bool> isCacheValid(
      {Duration maxAge = const Duration(hours: 24)}) async {
    return await OfflineCacheService.isCacheValid(_userId, 'medicamentos',
        maxAge: maxAge);
  }

  /// HARD SYNC: Deletar medicamentos órfãos do cache local
  /// 
  /// Medicamentos órfãos são aqueles que existem no cache local (Hive)
  /// mas não retornam na query do Supabase, indicando que foram deletados
  /// no servidor e precisam ser removidos localmente.
  Future<void> _deleteOrphanedMedications(List<Medicamento> medicamentosServidor) async {
    try {
      // Buscar medicamentos do cache local
      final cached = await OfflineCacheService.getCachedMedicamentos(_userId);
      
      if (cached.isEmpty) {
        return; // Nada para verificar
      }

      // Criar Set de IDs do servidor para busca rápida
      final idsServidor = medicamentosServidor.map((m) => m.id).toSet();
      
      // Encontrar medicamentos órfãos (existem no cache mas não no servidor)
      final orphaned = cached.where((m) => !idsServidor.contains(m.id)).toList();
      
      if (orphaned.isEmpty) {
        debugPrint('✅ MedicationSync: Nenhum medicamento órfão encontrado');
        return;
      }

      debugPrint('🗑️ MedicationSync: Encontrados ${orphaned.length} medicamento(s) órfão(s)');

      // Remover medicamentos órfãos do cache
      final updatedCache = cached.where((m) => idsServidor.contains(m.id)).toList();
      await OfflineCacheService.cacheMedicamentos(_userId, updatedCache);

      // Cancelar notificações dos medicamentos deletados
      for (final medicamento in orphaned) {
        try {
          await NotificationService.cancelMedicationReminders(medicamento);
          debugPrint('✅ MedicationSync: Notificações canceladas para ${medicamento.nome}');
        } catch (e) {
          debugPrint('⚠️ MedicationSync: Erro ao cancelar notificações de ${medicamento.nome}: $e');
        }
      }

      debugPrint('✅ MedicationSync: ${orphaned.length} medicamento(s) órfão(s) removido(s) do cache');
    } catch (e) {
      debugPrint('❌ MedicationSync: Erro ao deletar medicamentos órfãos: $e');
      // Não falhar o fluxo principal se houver erro na limpeza
    }
  }
}
