import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../core/utils/data_cleaner.dart';
import '../widgets/charts/adherence_bar_chart.dart';

class HistoricoEventosService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Buscar histórico de eventos de um perfil
  static Future<List<Map<String, dynamic>>> getHistoricoEventos(
      String perfilId) async {
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
          .order('data_prevista', ascending: false);

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
      await _client.from('historico_eventos').delete().eq('id', eventoId);
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
      final inicioDia =
          DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();
      // Usar data do dia seguinte para garantir cobertura total do dia atual
      final fimDia = DateTime(hoje.year, hoje.month, hoje.day)
          .add(const Duration(days: 1))
          .toIso8601String();

      // Buscar eventos de medicamentos concluídos hoje
      final response = await _client
          .from('historico_eventos')
          .select('medicamento_id, status')
          .eq('perfil_id', targetPerfilId)
          .filter('medicamento_id', 'in', '(${medicamentoIds.join(',')})')
          .gte('data_prevista', inicioDia)
          .lt('data_prevista', fimDia) // lt (less than) o início de amanhã
          .eq('status', 'confirmado');

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

  // Buscar dados de adesão dos últimos 7 dias
  static Future<List<DailyAdherence>> getDadosAdesaoUltimos7Dias(
      String perfilId) async {
    try {
      // Baseado no schema, tentar encontrar o perfil usando user_id
      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', perfilId)
          .maybeSingle();

      final targetPerfilId = perfilResponse?['id'] as String? ?? perfilId;

      final agora = DateTime.now();
      final seteDiasAtras =
          agora.subtract(const Duration(days: 6)); // Inclui hoje (7 dias total)
      final inicioPeriodo =
          DateTime(seteDiasAtras.year, seteDiasAtras.month, seteDiasAtras.day)
              .toIso8601String();
      final fimPeriodo = DateTime(agora.year, agora.month, agora.day)
          .add(const Duration(days: 1))
          .toIso8601String();

      // Buscar eventos dos últimos 7 dias (apenas medicamentos)
      final response = await _client
          .from('historico_eventos')
          .select('data_prevista, status, medicamento_id')
          .eq('perfil_id', targetPerfilId)
          .not('medicamento_id', 'is', null) // Apenas eventos de medicamentos
          .gte('data_prevista', inicioPeriodo)
          .lt('data_prevista', fimPeriodo);

      // Agrupar eventos por dia
      final Map<String, Map<String, int>> dadosPorDia = {};

      // Inicializar todos os dias dos últimos 7 dias
      for (int i = 0; i < 7; i++) {
        final data = agora.subtract(Duration(days: 6 - i));
        final chaveDia = DateFormat('yyyy-MM-dd').format(data);
        dadosPorDia[chaveDia] = {'taken': 0, 'missed': 0};
      }

      // Processar eventos
      for (var evento in response as List) {
        final dataPrevistaStr = evento['data_prevista'] as String?;
        if (dataPrevistaStr == null) continue;

        final dataPrevista = DateTime.parse(dataPrevistaStr);
        final chaveDia = DateFormat('yyyy-MM-dd').format(dataPrevista);

        if (dadosPorDia.containsKey(chaveDia)) {
          final status = evento['status'] as String? ?? 'pendente';
          if (status == 'confirmado') {
            dadosPorDia[chaveDia]!['taken'] =
                (dadosPorDia[chaveDia]!['taken'] ?? 0) + 1;
          } else {
            dadosPorDia[chaveDia]!['missed'] =
                (dadosPorDia[chaveDia]!['missed'] ?? 0) + 1;
          }
        }
      }

      // Converter para lista de DailyAdherence ordenada por data
      final List<DailyAdherence> dadosAdesao = [];
      for (int i = 0; i < 7; i++) {
        final data = agora.subtract(Duration(days: 6 - i));
        final chaveDia = DateFormat('yyyy-MM-dd').format(data);
        final dados = dadosPorDia[chaveDia] ?? {'taken': 0, 'missed': 0};

        // Formatar label do dia (abreviação do dia da semana)
        // DateTime.weekday retorna 1-7 (segunda=1, domingo=7)
        // Array: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
        // Índices:  [0,    1,    2,    3,    4,    5,    6]
        final diasSemana = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
        final diaSemana = diasSemana[data.weekday == 7 ? 0 : data.weekday];
        final diaMes = data.day;
        final mes = data.month;
        final dayLabel =
            '$diaSemana\n$diaMes/${mes.toString().padLeft(2, '0')}';

        dadosAdesao.add(DailyAdherence(
          dayLabel: dayLabel,
          taken: dados['taken'] ?? 0,
          missed: dados['missed'] ?? 0,
          date: data,
        ));
      }

      return dadosAdesao;
    } catch (error) {
      // Em caso de erro, retorna lista vazia ou com dados zerados
      final agora = DateTime.now();
      final List<DailyAdherence> dadosAdesao = [];
      final diasSemana = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

      for (int i = 0; i < 7; i++) {
        final data = agora.subtract(Duration(days: 6 - i));
        final diaSemana = diasSemana[data.weekday == 7 ? 0 : data.weekday];
        final diaMes = data.day;
        final mes = data.month;
        final dayLabel =
            '$diaSemana\n$diaMes/${mes.toString().padLeft(2, '0')}';

        dadosAdesao.add(DailyAdherence(
          dayLabel: dayLabel,
          taken: 0,
          missed: 0,
          date: data,
        ));
      }

      return dadosAdesao;
    }
  }
}
