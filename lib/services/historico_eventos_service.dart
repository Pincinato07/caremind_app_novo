import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/data_cleaner.dart';

class HistoricoEventosService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Buscar histórico de eventos de um perfil
  static Future<List<Map<String, dynamic>>> getHistoricoEventos(String perfilId) async {
    try {
      // Baseado no schema, tentar encontrar o perfil usando user_id
      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', perfilId)
          .maybeSingle();
      
      final targetPerfilId = perfilResponse?['id'] as String? ?? perfilId;
      
      final response = await _client
          .from('historico_eventos')
          .select()
          .eq('perfil_id', targetPerfilId)
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

  // Verificar quais medicamentos foram concluídos hoje
  static Future<Map<int, bool>> checkMedicamentosConcluidosHoje(
      String perfilId, List<int> medicamentoIds) async {
    if (medicamentoIds.isEmpty) return {};

    try {
      // Baseado no schema, tentar encontrar o perfil usando user_id
      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', perfilId)
          .maybeSingle();
      
      final targetPerfilId = perfilResponse?['id'] as String? ?? perfilId;

      final hoje = DateTime.now();
      // Ajuste para garantir comparação correta com strings ISO
      final inicioDia = DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();
      // Usar data do dia seguinte para garantir cobertura total do dia atual
      final fimDia = DateTime(hoje.year, hoje.month, hoje.day).add(const Duration(days: 1)).toIso8601String();

      // Buscar eventos de medicamentos concluídos hoje
      final response = await _client
          .from('historico_eventos')
          .select('medicamento_id, status')
          .eq('perfil_id', targetPerfilId)
          .in_('medicamento_id', medicamentoIds)
          .gte('data_prevista', inicioDia)
          .lt('data_prevista', fimDia) // lt (less than) o início de amanhã
          .eq('status', 'concluido');

      final Map<int, bool> statusMap = {};
      
      // Inicializar tudo como false
      for (var id in medicamentoIds) {
        statusMap[id] = false;
      }

      // Marcar os encontrados como true
      for (var evento in response as List) {
        if (evento['medicamento_id'] != null) {
          final medId = evento['medicamento_id'] as int;
          statusMap[medId] = true;
        }
      }

      return statusMap;
    } catch (error) {
      // Em caso de erro, retorna mapa com false (seguro)
      // debugPrint('Erro ao verificar status: $error');
      return {for (var id in medicamentoIds) id: false};
    }
  }
}
