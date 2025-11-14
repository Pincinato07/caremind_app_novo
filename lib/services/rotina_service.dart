import 'package:supabase_flutter/supabase_flutter.dart';

class RotinaService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Buscar todas as rotinas de um usuário
  static Future<List<Map<String, dynamic>>> getRotinas(String userId) async {
    try {
      final response = await _client
          .from('rotinas')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Erro ao buscar rotinas: $error');
    }
  }

  // Adicionar uma nova rotina
  static Future<Map<String, dynamic>> addRotina(
      Map<String, dynamic> rotina) async {
    try {
      final response = await _client
          .from('rotinas')
          .insert(rotina)
          .select()
          .single();

      return response;
    } catch (error) {
      throw Exception('Erro ao adicionar rotina: $error');
    }
  }

  // Atualizar uma rotina existente
  static Future<Map<String, dynamic>> updateRotina(
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
      throw Exception('Erro ao atualizar rotina: $error');
    }
  }

  // Deletar uma rotina
  static Future<void> deleteRotina(int rotinaId) async {
    try {
      await _client
          .from('rotinas')
          .delete()
          .eq('id', rotinaId);
    } catch (error) {
      throw Exception('Erro ao deletar rotina: $error');
    }
  }
}
