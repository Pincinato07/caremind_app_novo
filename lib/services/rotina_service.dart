import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';
import '../core/utils/data_cleaner.dart';
import 'historico_eventos_service.dart';
import 'rotina_notification_service.dart';
import 'rotina_analytics_service.dart';

class RotinaService {
  final SupabaseClient _client;

  RotinaService(this._client);

  // Buscar todas as rotinas de um usuário
  // Atualizado para usar user_id (campo correto baseado no schema)
  Future<List<Map<String, dynamic>>> getRotinas(String userId) async {
    try {
      // Baseado no schema, obter o perfil_id do usuário usando user_id
      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      final perfilId = perfilResponse?['id'] as String?;

      // Usar perfil_id se disponível, senão usar user_id (compatibilidade durante transição)
      final response = await _client
          .from('rotinas')
          .select()
          .or(perfilId != null
              ? 'perfil_id.eq.$perfilId'
              : 'perfil_id.eq.$userId')
          .order('created_at', ascending: false);

      final rotinas = List<Map<String, dynamic>>.from(response);
      
      // Migrar dados legados automaticamente
      for (final rotina in rotinas) {
        await _migrateLegacyDataIfNeeded(rotina);
      }

      return rotinas;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  /// Migra dados legados que usam campo 'horario' para formato 'frequencia'
  Future<void> _migrateLegacyDataIfNeeded(Map<String, dynamic> rotina) async {
    try {
      final rotinaId = rotina['id'] as int?;
      if (rotinaId == null) return;

      final frequencia = rotina['frequencia'];
      final horarioLegado = rotina['horario'] as String?;

      // Se já tem frequencia ou não tem horario legado, não precisa migrar
      if (frequencia != null || horarioLegado == null || horarioLegado.isEmpty) {
        return;
      }

      // Migrar horario legado para frequencia
      final frequenciaMigrada = {
        'tipo': 'diario',
        'horarios': [horarioLegado],
      };

      debugPrint(
          '🔄 RotinaService: Migrando rotina $rotinaId de horario legado para frequencia');

      await _client
          .from('rotinas')
          .update({
            'frequencia': frequenciaMigrada,
            // Remover campo horario se existir (não está no schema, mas pode estar em dados antigos)
          })
          .eq('id', rotinaId);

      // Atualizar o objeto local
      rotina['frequencia'] = frequenciaMigrada;
      rotina.remove('horario');

      debugPrint('✅ RotinaService: Rotina $rotinaId migrada com sucesso');
    } catch (error) {
      debugPrint(
          '⚠️ RotinaService: Erro ao migrar rotina ${rotina['id']}: $error');
      // Não lança exceção para não interromper o fluxo
    }
  }

  /// Migra todas as rotinas legadas de um usuário
  Future<int> migrarRotinasLegadas(String userId) async {
    try {
      debugPrint('🔄 RotinaService: Iniciando migração de rotinas legadas');

      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      final perfilId = perfilResponse?['id'] as String?;

      // Buscar todas as rotinas e filtrar as que precisam de migração
      final response = await _client
          .from('rotinas')
          .select()
          .or(perfilId != null
              ? 'perfil_id.eq.$perfilId'
              : 'perfil_id.eq.$userId');

      final todasRotinas = List<Map<String, dynamic>>.from(response);
      
      // Filtrar rotinas que precisam de migração (têm horario mas não têm frequencia)
      final rotinasLegadas = todasRotinas.where((rotina) {
        final frequencia = rotina['frequencia'];
        final horarioLegado = rotina['horario'] as String?;
        return (frequencia == null || frequencia.toString().isEmpty) &&
            horarioLegado != null &&
            horarioLegado.isNotEmpty;
      }).toList();
      
      int migradas = 0;

      for (final rotina in rotinasLegadas) {
        final rotinaId = rotina['id'] as int?;
        final horarioLegado = rotina['horario'] as String?;

        if (rotinaId == null || horarioLegado == null || horarioLegado.isEmpty) {
          continue;
        }

        final frequenciaMigrada = {
          'tipo': 'diario',
          'horarios': [horarioLegado],
        };

        await _client
            .from('rotinas')
            .update({'frequencia': frequenciaMigrada})
            .eq('id', rotinaId);

        migradas++;
      }

      debugPrint(
          '✅ RotinaService: Migração concluída. $migradas rotina(s) migrada(s)');
      
      // Rastrear analytics de migração
      if (migradas > 0) {
        try {
          await RotinaAnalyticsService.trackMigracaoLegada(
            rotinasMigradas: migradas,
            perfilId: perfilId ?? userId,
          );
        } catch (e) {
          debugPrint('⚠️ Erro ao rastrear analytics de migração: $e');
        }
      }
      
      return migradas;
    } catch (error) {
      debugPrint('❌ RotinaService: Erro na migração: $error');
      throw ErrorHandler.toAppException(error);
    }
  }

  // Adicionar uma nova rotina
  Future<Map<String, dynamic>> addRotina(Map<String, dynamic> rotina) async {
    try {
      // Garantir que perfil_id ou user_id estejam presentes
      if (rotina['perfil_id'] == null ||
          (rotina['perfil_id'] as String).isEmpty) {
        final userId = rotina['user_id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          // Baseado no schema, buscar perfil usando user_id
          final perfilResponse = await _client
              .from('perfis')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

          if (perfilResponse != null) {
            rotina['perfil_id'] = perfilResponse['id'] as String;
          } else {
            // Se não encontrou perfil, usar o user_id como fallback
            rotina['perfil_id'] = userId;
          }
        } else {
          throw Exception('perfil_id é obrigatório');
        }
      }

      // Garantir que created_at esteja presente
      if (rotina['created_at'] == null) {
        rotina['created_at'] = DateTime.now().toIso8601String();
      }

      // CORRIGIDO: Usar concluido (boolean) em vez de concluida (tabela usa concluido)
      if (rotina['concluido'] == null) {
        rotina['concluido'] = false;
      }

      // Limpar dados antes de inserir (remove strings vazias, mas mantém campos obrigatórios)
      final cleanedData = DataCleaner.cleanData(
        rotina,
        fieldsToKeepEmpty: ['perfil_id'],
      );

      // Garantir que pelo menos perfil_id ou user_id estejam presentes após limpeza
      if (cleanedData['perfil_id'] == null) {
        throw Exception('É necessário perfil_id para criar rotina');
      }

      debugPrint('📤 RotinaService: Dados para inserção: $cleanedData');

      final response =
          await _client.from('rotinas').insert(cleanedData).select().single();

      // Agendar notificações para a nova rotina
      try {
        await RotinaNotificationService.scheduleRotinaNotifications(response);
      } catch (e) {
        debugPrint('⚠️ Erro ao agendar notificações para nova rotina: $e');
        // Não relançar erro - rotina foi criada com sucesso
      }

      // Rastrear analytics
      try {
        final frequencia = response['frequencia'] as Map<String, dynamic>?;
        final tipoFrequencia = frequencia?['tipo'] as String? ?? 'desconhecido';
        await RotinaAnalyticsService.trackRotinaCriada(
          rotinaId: response['id'] as int,
          tipoFrequencia: tipoFrequencia,
          perfilId: response['perfil_id'] as String?,
        );
      } catch (e) {
        debugPrint('⚠️ Erro ao rastrear analytics de criação: $e');
      }

      return response;
    } catch (error) {
      debugPrint(
          '❌ RotinaService: Erro ao adicionar rotina: ${error.toString()}');
      debugPrint('❌ RotinaService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint(
            '❌ RotinaService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ RotinaService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }

  // Atualizar uma rotina existente
  Future<Map<String, dynamic>> updateRotina(
    int rotinaId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Buscar rotina antes de atualizar para analytics
      Map<String, dynamic>? rotinaAntes;
      try {
        final rotinaAntesResponse = await _client
            .from('rotinas')
            .select()
            .eq('id', rotinaId)
            .maybeSingle();
        rotinaAntes = rotinaAntesResponse;
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar rotina antes de atualizar: $e');
      }

      // Não remover created_at se estiver presente (pode ser necessário para histórico)
      // Limpar dados antes de atualizar (remove strings vazias, mas mantém campos importantes)
      final cleanedUpdates = DataCleaner.cleanData(
        updates,
        fieldsToKeepEmpty: ['perfil_id'],
      );

      debugPrint('📤 RotinaService: Dados para atualização: $cleanedUpdates');

      final response = await _client
          .from('rotinas')
          .update(cleanedUpdates)
          .eq('id', rotinaId)
          .select()
          .single();

      // Reagendar notificações para a rotina atualizada
      try {
        await RotinaNotificationService.scheduleRotinaNotifications(response);
      } catch (e) {
        debugPrint('⚠️ Erro ao reagendar notificações para rotina atualizada: $e');
        // Não relançar erro - rotina foi atualizada com sucesso
      }

      // Rastrear analytics
      try {
        final frequenciaAntes = rotinaAntes?['frequencia'] as Map<String, dynamic>?;
        final frequenciaDepois = response['frequencia'] as Map<String, dynamic>?;
        await RotinaAnalyticsService.trackRotinaAtualizada(
          rotinaId: rotinaId,
          tipoFrequenciaAnterior: frequenciaAntes?['tipo'] as String?,
          tipoFrequenciaNovo: frequenciaDepois?['tipo'] as String?,
          perfilId: response['perfil_id'] as String?,
        );
      } catch (e) {
        debugPrint('⚠️ Erro ao rastrear analytics de atualização: $e');
      }

      return response;
    } catch (error) {
      debugPrint(
          '❌ RotinaService: Erro ao atualizar rotina: ${error.toString()}');
      debugPrint('❌ RotinaService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint(
            '❌ RotinaService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ RotinaService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }

  // Deletar uma rotina
  Future<void> deleteRotina(int rotinaId) async {
    try {
      // Buscar rotina antes de deletar para analytics
      Map<String, dynamic>? rotina;
      try {
        final rotinaResponse = await _client
            .from('rotinas')
            .select()
            .eq('id', rotinaId)
            .maybeSingle();
        rotina = rotinaResponse;
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar rotina antes de deletar: $e');
      }

      // Cancelar notificações antes de deletar
      try {
        await RotinaNotificationService.cancelRotinaNotifications(rotinaId);
      } catch (e) {
        debugPrint('⚠️ Erro ao cancelar notificações da rotina: $e');
        // Continuar mesmo com erro
      }

      await _client.from('rotinas').delete().eq('id', rotinaId);

      // Rastrear analytics
      try {
        await RotinaAnalyticsService.trackRotinaExcluida(
          rotinaId: rotinaId,
          perfilId: rotina?['perfil_id'] as String?,
        );
      } catch (e) {
        debugPrint('⚠️ Erro ao rastrear analytics de exclusão: $e');
      }
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Marcar rotina como concluída
  // CORRIGIDO: Usar concluido (boolean) em vez de concluida (tabela usa concluido)
  Future<Map<String, dynamic>> toggleConcluida(
    int rotinaId,
    bool concluido,
  ) async {
    try {
      debugPrint(
          '📤 RotinaService: Marcando rotina $rotinaId como concluído: $concluido');

      final response = await _client
          .from('rotinas')
          .update({'concluido': concluido})
          .eq('id', rotinaId)
          .select()
          .single();

      // Registrar no histórico se foi concluída
      if (concluido) {
        try {
          final perfilId = response['perfil_id'];
          if (perfilId != null) {
            await HistoricoEventosService.addEvento({
              'perfil_id': perfilId,
              'tipo_evento': 'rotina_concluida',
              'evento_id': rotinaId,
              'data_prevista': DateTime.now().toIso8601String(),
              'status': 'confirmado',
              'titulo': response['titulo'] ?? response['nome'] ?? 'Rotina',
              'descricao': 'Rotina marcada como concluída',
              'rotina_id': rotinaId, // Campo específico se existir no schema
            });
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao registrar histórico da rotina: $e');
        }
      }

      // Rastrear analytics
      try {
        await RotinaAnalyticsService.trackRotinaConcluida(
          rotinaId: rotinaId,
          concluida: concluido,
          perfilId: response['perfil_id'] as String?,
        );
      } catch (e) {
        debugPrint('⚠️ Erro ao rastrear analytics de conclusão: $e');
      }

      return response;
    } catch (error) {
      debugPrint(
          '❌ RotinaService: Erro ao marcar rotina como concluída: ${error.toString()}');
      debugPrint('❌ RotinaService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint(
            '❌ RotinaService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ RotinaService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }
}
