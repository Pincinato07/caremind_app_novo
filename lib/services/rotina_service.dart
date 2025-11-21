import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';

class RotinaService {
  final SupabaseClient _client;

  RotinaService(this._client);

  // Buscar todas as rotinas de um usuário
  // Atualizado para usar perfil_id (com fallback para user_id durante transição)
  Future<List<Map<String, dynamic>>> getRotinas(String userId) async {
    try {
      // Primeiro, obter o perfil_id do usuário
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
              ? 'perfil_id.eq.$perfilId,user_id.eq.$userId'
              : 'user_id.eq.$userId')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Adicionar uma nova rotina
  Future<Map<String, dynamic>> addRotina(Map<String, dynamic> rotina) async {
    try {
      // Se não tem perfil_id, buscar do user_id
      if (rotina['perfil_id'] == null && rotina['user_id'] != null) {
        final perfilResponse = await _client
            .from('perfis')
            .select('id')
            .eq('user_id', rotina['user_id'] as String)
            .maybeSingle();
        
        if (perfilResponse != null) {
          rotina['perfil_id'] = perfilResponse['id'] as String;
        }
      }
      
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
