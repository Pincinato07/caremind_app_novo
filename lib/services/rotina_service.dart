import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';
import '../core/utils/data_cleaner.dart';
import 'historico_eventos_service.dart';

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

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Adicionar uma nova rotina
  Future<Map<String, dynamic>> addRotina(Map<String, dynamic> rotina) async {
    try {
      // Garantir que perfil_id ou user_id estejam presentes
      if (rotina['perfil_id'] == null || (rotina['perfil_id'] as String).isEmpty) {
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

      // Garantir que concluida esteja presente
      if (rotina['concluida'] == null) {
        rotina['concluida'] = false;
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
      
      final response = await _client
          .from('rotinas')
          .insert(cleanedData)
          .select()
          .single();

      return response;
    } catch (error) {
      debugPrint('❌ RotinaService: Erro ao adicionar rotina: ${error.toString()}');
      debugPrint('❌ RotinaService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint('❌ RotinaService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
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

      return response;
    } catch (error) {
      debugPrint('❌ RotinaService: Erro ao atualizar rotina: ${error.toString()}');
      debugPrint('❌ RotinaService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint('❌ RotinaService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
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
      await _client.from('rotinas').delete().eq('id', rotinaId);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Marcar rotina como concluída
  Future<Map<String, dynamic>> toggleConcluida(
    int rotinaId,
    bool concluida,
  ) async {
    try {
      debugPrint('📤 RotinaService: Marcando rotina $rotinaId como concluída: $concluida');
      
      final response = await _client
          .from('rotinas')
          .update({'concluida': concluida})
          .eq('id', rotinaId)
          .select()
          .single();

      // Registrar no histórico se foi concluída
      if (concluida) {
        try {
          final perfilId = response['perfil_id'];
          if (perfilId != null) {
            await HistoricoEventosService.addEvento({
              'perfil_id': perfilId,
              'tipo_evento': 'rotina_concluida',
              'evento_id': rotinaId,
              'data_prevista': DateTime.now().toIso8601String(),
              'status': 'concluido',
              'titulo': response['titulo'] ?? response['nome'] ?? 'Rotina',
              'descricao': 'Rotina marcada como concluída',
              'rotina_id': rotinaId, // Campo específico se existir no schema
            });
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao registrar histórico da rotina: $e');
        }
      }

      return response;
    } catch (error) {
      debugPrint('❌ RotinaService: Erro ao marcar rotina como concluída: ${error.toString()}');
      debugPrint('❌ RotinaService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint('❌ RotinaService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ RotinaService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }
}
