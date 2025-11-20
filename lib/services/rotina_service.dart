import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';

class RotinaService {
  final SupabaseClient _client;

  RotinaService(this._client);

  // Buscar todas as rotinas de um usuário
  Future<List<Map<String, dynamic>>> getRotinas(String userId) async {
    try {
      final response = await _client
          .from('rotinas')
          .select()
          .eq('perfil_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Adicionar uma nova rotina
  Future<Map<String, dynamic>> addRotina(Map<String, dynamic> rotina) async {
    try {
      final response = await _client
          .from('rotinas')
          .insert(rotina)
          .select()
          .single();

      return response;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Atualizar uma rotina existente
  Future<Map<String, dynamic>> updateRotina(
    int rotinaId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _client
          .from('rotinas')
          .update(updates)
          .eq('id', rotinaId)
          .select()
          .single();

      return response;
    } catch (error) {
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
      final response = await _client
          .from('rotinas')
          .update({'concluida': concluida})
          .eq('id', rotinaId)
          .select()
          .single();

      return response;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }
}
