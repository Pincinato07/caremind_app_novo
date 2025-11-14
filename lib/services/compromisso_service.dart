import 'package:supabase_flutter/supabase_flutter.dart';

class CompromissoService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Buscar todos os compromissos de um perfil
  static Future<List<Map<String, dynamic>>> getCompromissos(String perfilId) async {
    try {
      final response = await _client
          .from('compromissos')
          .select()
          .eq('perfil_id', perfilId)
          .order('data_hora', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Erro ao buscar compromissos: $error');
    }
  }

  // Buscar compromissos futuros
  static Future<List<Map<String, dynamic>>> getProximosCompromissos(
      String perfilId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _client
          .from('compromissos')
          .select()
          .eq('perfil_id', perfilId)
          .gte('data_hora', now)
          .order('data_hora', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Erro ao buscar próximos compromissos: $error');
    }
  }

  // Adicionar um novo compromisso
  static Future<Map<String, dynamic>> addCompromisso(
      Map<String, dynamic> compromisso) async {
    try {
      final response = await _client
          .from('compromissos')
          .insert(compromisso)
          .select()
          .single();

      return response;
    } catch (error) {
      throw Exception('Erro ao adicionar compromisso: $error');
    }
  }

  // Atualizar um compromisso existente
  static Future<Map<String, dynamic>> updateCompromisso(
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
      throw Exception('Erro ao atualizar compromisso: $error');
    }
  }

  // Deletar um compromisso
  static Future<void> deleteCompromisso(int compromissoId) async {
    try {
      await _client
          .from('compromissos')
          .delete()
          .eq('id', compromissoId);
    } catch (error) {
      throw Exception('Erro ao deletar compromisso: $error');
    }
  }
}
