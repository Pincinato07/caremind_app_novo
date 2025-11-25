import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/data_cleaner.dart';

class HistoricoEventosService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Buscar histórico de eventos de um perfil
  static Future<List<Map<String, dynamic>>> getHistoricoEventos(String perfilId) async {
    try {
      final response = await _client
          .from('historico_eventos')
          .select()
          .eq('perfil_id', perfilId)
          .order('data_hora', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Erro ao buscar histórico de eventos: $error');
    }
  }

  // Adicionar um novo evento ao histórico
  static Future<Map<String, dynamic>> addEvento(
      Map<String, dynamic> evento) async {
    try {
      // Limpar dados antes de inserir (remove strings vazias)
      final cleanedData = DataCleaner.cleanData(evento);
      
      final response = await _client
          .from('historico_eventos')
          .insert(cleanedData)
          .select()
          .single();

      return response;
    } catch (error) {
      throw Exception('Erro ao adicionar evento: $error');
    }
  }

  // Atualizar um evento existente
  static Future<Map<String, dynamic>> updateEvento(
    int eventoId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Limpar dados antes de atualizar (remove strings vazias)
      final cleanedUpdates = DataCleaner.cleanData(updates);
      
      final response = await _client
          .from('historico_eventos')
          .update(cleanedUpdates)
          .eq('id', eventoId)
          .select()
          .single();

      return response;
    } catch (error) {
      throw Exception('Erro ao atualizar evento: $error');
    }
  }

  // Deletar um evento
  static Future<void> deleteEvento(int eventoId) async {
    try {
      await _client
          .from('historico_eventos')
          .delete()
          .eq('id', eventoId);
    } catch (error) {
      throw Exception('Erro ao deletar evento: $error');
    }
  }
}
