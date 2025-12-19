import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';
import '../core/utils/data_cleaner.dart';

class CompromissoService {
  final SupabaseClient _client;

  CompromissoService(this._client);

  // Buscar todos os compromissos de um usuário
  Future<List<Map<String, dynamic>>> getCompromissos(String userId) async {
    try {
      debugPrint(
          '📤 CompromissoService: Buscando compromissos para userId: $userId');

      // Baseado no schema, obter o perfil_id do usuário usando user_id
      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      final perfilId = perfilResponse?['id'] as String?;

      // Usar perfil_id se disponível, senão usar user_id (compatibilidade durante transição)
      final response = await _client
          .from('compromissos')
          .select()
          .or(perfilId != null
              ? 'perfil_id.eq.$perfilId'
              : 'perfil_id.eq.$userId')
          .order('data_hora', ascending: true);

      debugPrint(
          '✅ CompromissoService: ${response.length} compromisso(s) encontrado(s)');
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint(
          '❌ CompromissoService: Erro ao buscar compromissos: ${error.toString()}');
      debugPrint('❌ CompromissoService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint(
            '❌ CompromissoService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ CompromissoService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }

  // Buscar compromissos futuros
  Future<List<Map<String, dynamic>>> getProximosCompromissos(
      String userId) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Primeiro, obter o perfil_id do usuário
      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      final perfilId = perfilResponse?['id'] as String?;

      // Usar perfil_id se disponível, senão usar user_id (compatibilidade durante transição)
      final response = await _client
          .from('compromissos')
          .select()
          .or(perfilId != null
              ? 'perfil_id.eq.$perfilId'
              : 'perfil_id.eq.$userId')
          .gte('data_hora', now)
          .order('data_hora', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Adicionar um novo compromisso
  Future<Map<String, dynamic>> addCompromisso(
      Map<String, dynamic> compromisso) async {
    try {
      // Garantir que perfil_id ou user_id estejam presentes
      if (compromisso['perfil_id'] == null ||
          (compromisso['perfil_id'] as String).isEmpty) {
        final userId = compromisso['user_id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          final perfilResponse = await _client
              .from('perfis')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

          if (perfilResponse != null) {
            compromisso['perfil_id'] = perfilResponse['id'] as String;
          } else {
            // Se não encontrou perfil, usar o user_id como fallback
            compromisso['perfil_id'] = userId;
          }
        } else {
          throw Exception('perfil_id é obrigatório');
        }
      }

      // Limpar dados antes de inserir (remove strings vazias)
      final cleanedData = DataCleaner.cleanData(compromisso);

      debugPrint('📤 CompromissoService: Dados para inserção: $cleanedData');

      final response = await _client
          .from('compromissos')
          .insert(cleanedData)
          .select()
          .single();

      debugPrint('✅ CompromissoService: Compromisso inserido com sucesso');
      return response;
    } catch (error) {
      debugPrint(
          '❌ CompromissoService: Erro ao adicionar compromisso: ${error.toString()}');
      debugPrint('❌ CompromissoService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint(
            '❌ CompromissoService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ CompromissoService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }

  // Atualizar um compromisso existente
  Future<Map<String, dynamic>> updateCompromisso(
    String compromissoId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Limpar dados antes de atualizar (remove strings vazias)
      final cleanedUpdates = DataCleaner.cleanData(updates);

      final response = await _client
          .from('compromissos')
          .update(cleanedUpdates)
          .eq('id', compromissoId)
          .select()
          .single();

      return response;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Deletar um compromisso
  Future<void> deleteCompromisso(String compromissoId) async {
    try {
      await _client.from('compromissos').delete().eq('id', compromissoId);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }
}
