import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';

class CompromissoService {
  final SupabaseClient _client;

  CompromissoService(this._client);

  // Buscar todos os compromissos de um usuário
  Future<List<Map<String, dynamic>>> getCompromissos(String userId) async {
    try {
      final response = await _client
          .from('compromissos')
          .select()
          .eq('user_id', userId)
          .order('data_hora', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Buscar compromissos futuros
  Future<List<Map<String, dynamic>>> getProximosCompromissos(
      String userId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _client
          .from('compromissos')
          .select()
          .eq('user_id', userId)
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
      final response = await _client
          .from('compromissos')
          .insert(compromisso)
          .select()
          .single();

      return response;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Atualizar um compromisso existente
  Future<Map<String, dynamic>> updateCompromisso(
    int compromissoId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _client
          .from('compromissos')
          .update(updates)
          .eq('id', compromissoId)
          .select()
          .single();

      return response;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Deletar um compromisso
  Future<void> deleteCompromisso(int compromissoId) async {
    try {
      await _client.from('compromissos').delete().eq('id', compromissoId);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Marcar compromisso como concluído
  Future<Map<String, dynamic>> toggleConcluido(
    int compromissoId,
    bool concluido,
  ) async {
    try {
      final response = await _client
          .from('compromissos')
          .update({'concluido': concluido})
          .eq('id', compromissoId)
          .select()
          .single();

      return response;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }
}
