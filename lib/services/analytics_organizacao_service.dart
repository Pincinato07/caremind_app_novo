import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_organizacao.dart';
import '../models/medicamento.dart';
import 'idoso_organizacao_service.dart';

/// Serviço para buscar analytics de organização
class AnalyticsOrganizacaoService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Obter analytics completos de uma organização
  Future<AnalyticsOrganizacao> obterAnalyticsOrganizacao(
    String organizacaoId, {
    int dias = 30,
  }) async {
    try {
      // Buscar idosos da organização
      final idosoService = IdosoOrganizacaoService();
      final idosos = await idosoService.listarIdosos(organizacaoId);
      final idososIds = idosos.map((i) => i.perfilId).toList();

      if (idososIds.isEmpty) {
        return AnalyticsOrganizacao(
          totalIdosos: 0,
          totalMedicamentos: 0,
          totalRotinas: 0,
          medicamentosPendentes: 0,
          eventosHoje: 0,
          eventosAtrasados: 0,
          taxaAdesaoGeral: 0.0,
          adesaoPorIdoso: [],
          medicamentosStats: [],
          eventosPorDia: [],
        );
      }

      // Buscar medicamentos de todos os idosos
      final medicamentosData = await _obterMedicamentosPorPerfis(idososIds);
      final medicamentos = medicamentosData
          .map((m) => Medicamento.fromMap(m))
          .toList();
      
      // Buscar rotinas de todos os idosos
      final rotinas = await _obterRotinasPorPerfis(idososIds);

      // Buscar eventos dos últimos N dias
      final hoje = DateTime.now();
      final eventosPorDia = <EventoPorDia>[];
      int totalEventos = 0;
      int totalConcluidos = 0;
      int eventosAtrasados = 0;

      for (int i = dias - 1; i >= 0; i--) {
        final data = DateTime(hoje.year, hoje.month, hoje.day)
            .subtract(Duration(days: i));
        final eventos = await _obterEventosDoDiaMultiplos(idososIds, data);

        // Banco usa 'confirmado', não 'concluido'
        final concluidos = eventos
            .where((e) => e['status'] == 'confirmado')
            .length;
        final pendentes = eventos
            .where((e) => e['status'] == 'pendente')
            .length;
        final atrasados = eventos
            .where((e) {
              if (e['status'] != 'pendente') return false;
              final horarioStr = e['horario_programado'] as String?;
              if (horarioStr == null) return false;
              try {
                final horario = DateTime.parse(horarioStr);
                return horario.isBefore(DateTime.now());
              } catch (_) {
                return false;
              }
            })
            .length;

        eventosPorDia.add(EventoPorDia(
          data: data.toIso8601String().split('T')[0],
          total: eventos.length,
          concluidos: concluidos,
          pendentes: pendentes,
          atrasados: atrasados,
        ));

        totalEventos += eventos.length;
        totalConcluidos += concluidos;
        eventosAtrasados += atrasados;
      }

      // Eventos de hoje
      final eventosHoje = await _obterEventosDoDiaMultiplos(idososIds, hoje);

      // Calcular adesão por idoso (últimos 30 dias agregados)
      final adesaoPorIdoso = <AdesaoPorIdoso>[];

      for (final idoso in idosos) {
        int totalEventosIdoso = 0;
        int totalConcluidosIdoso = 0;

        // Agregar eventos dos últimos 30 dias
        for (int i = 0; i < 30; i++) {
          final data = hoje.subtract(Duration(days: i));
          final eventos = await _obterEventosDoDiaMultiplos([idoso.perfilId], data);
          totalEventosIdoso += eventos.length;
          totalConcluidosIdoso += eventos
              .where((e) => e['status'] == 'confirmado')
              .length;
        }

        final taxa = totalEventosIdoso > 0
            ? (totalConcluidosIdoso / totalEventosIdoso) * 100
            : 0.0;

        adesaoPorIdoso.add(AdesaoPorIdoso(
          idosoId: idoso.perfilId,
          idosoNome: idoso.nomePerfil ?? 'Sem nome',
          totalEventos: totalEventosIdoso,
          eventosConcluidos: totalConcluidosIdoso,
          taxaAdesao: taxa,
        ));
      }

      // Stats de medicamentos por idoso
      final medicamentosStats = <MedicamentoStats>[];
      final agora = DateTime.now();

      for (final idoso in idosos) {
        final medsIdoso = medicamentos
            .where((m) => m.perfilId == idoso.perfilId)
            .toList();
        final pendentes = medsIdoso.length; // Simplificado - todos são considerados pendentes se não concluídos

        // Buscar eventos atrasados do idoso
        final eventosHojeIdoso = await _obterEventosDoDiaMultiplos([idoso.perfilId], agora);
        final eventosAtrasadosIdoso = eventosHojeIdoso.where((evento) {
          if (evento['status'] != 'pendente') return false;
          final horarioStr = evento['horario_programado'] as String?;
          if (horarioStr == null) return false;
          try {
            final horario = DateTime.parse(horarioStr);
            return horario.isBefore(agora);
          } catch (_) {
            return false;
          }
        }).length;

        medicamentosStats.add(MedicamentoStats(
          idosoId: idoso.perfilId,
          idosoNome: idoso.nomePerfil ?? 'Sem nome',
          totalMedicamentos: medsIdoso.length,
          medicamentosPendentes: pendentes,
          medicamentosAtrasados: eventosAtrasadosIdoso,
        ));
      }

      final taxaAdesaoGeral =
          totalEventos > 0 ? (totalConcluidos / totalEventos) * 100 : 0.0;
      final medicamentosPendentes = medicamentos.length; // Simplificado

      return AnalyticsOrganizacao(
        totalIdosos: idosos.length,
        totalMedicamentos: medicamentos.length,
        totalRotinas: rotinas.length,
        medicamentosPendentes: medicamentosPendentes,
        eventosHoje: eventosHoje.length,
        eventosAtrasados: eventosAtrasados,
        taxaAdesaoGeral: taxaAdesaoGeral,
        adesaoPorIdoso: adesaoPorIdoso,
        medicamentosStats: medicamentosStats,
        eventosPorDia: eventosPorDia,
      );
    } on SocketException {
      throw Exception(
          'Erro de conexão. Verifique sua internet e tente novamente.');
    } catch (e) {
      throw Exception('Erro ao obter analytics: $e');
    }
  }

  /// Buscar medicamentos por múltiplos perfis
  Future<List<Map<String, dynamic>>> _obterMedicamentosPorPerfis(
      List<String> perfilIds) async {
    if (perfilIds.isEmpty) return [];

    try {
      // Usar .inFilter() para buscar múltiplos perfis
      final response = await _client
          .from('medicamentos')
          .select()
          .inFilter('perfil_id', perfilIds);

      return (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Erro ao buscar medicamentos: $e');
    }
  }

  /// Buscar rotinas por múltiplos perfis
  Future<List<Map<String, dynamic>>> _obterRotinasPorPerfis(List<String> perfilIds) async {
    if (perfilIds.isEmpty) return [];

    try {
      final response = await _client
          .from('rotinas')
          .select()
          .inFilter('perfil_id', perfilIds);

      return (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Erro ao buscar rotinas: $e');
    }
  }

  /// Buscar eventos do dia para múltiplos perfis
  Future<List<Map<String, dynamic>>> _obterEventosDoDiaMultiplos(
    List<String> perfilIds,
    DateTime data,
  ) async {
    if (perfilIds.isEmpty) return [];

    try {
      final inicioDia = DateTime(data.year, data.month, data.day).toIso8601String();
      final fimDia = DateTime(data.year, data.month, data.day)
          .add(const Duration(days: 1))
          .toIso8601String();

      final response = await _client
          .from('historico_eventos')
          .select()
          .inFilter('perfil_id', perfilIds)
          .gte('data_prevista', inicioDia)
          .lt('data_prevista', fimDia);

      return (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Erro ao buscar eventos: $e');
    }
  }
}

