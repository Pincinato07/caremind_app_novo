import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'historico_eventos_service.dart';
import '../models/medicamento.dart';
import 'idoso_organizacao_service.dart';

/// Modelo para medicamento consolidado (com informações do idoso)
class MedicamentoConsolidado {
  final Medicamento medicamento;
  final String idosoId;
  final String idosoNome;
  final String? quarto;
  final String? setor;

  MedicamentoConsolidado({
    required this.medicamento,
    required this.idosoId,
    required this.idosoNome,
    this.quarto,
    this.setor,
  });
}

/// Modelo para rotina consolidada (com informações do idoso)
class RotinaConsolidada {
  final Map<String, dynamic> rotina;
  final String idosoId;
  final String idosoNome;
  final String? quarto;
  final String? setor;

  RotinaConsolidada({
    required this.rotina,
    required this.idosoId,
    required this.idosoNome,
    this.quarto,
    this.setor,
  });
}

/// Modelo para compromisso consolidado (com informações do idoso)
class CompromissoConsolidado {
  final Map<String, dynamic> compromisso;
  final String idosoId;
  final String idosoNome;
  final String? quarto;
  final String? setor;

  CompromissoConsolidado({
    required this.compromisso,
    required this.idosoId,
    required this.idosoNome,
    this.quarto,
    this.setor,
  });
}

/// Serviço para buscar dados consolidados da organização
class ConsolidadoOrganizacaoService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Obter medicamentos consolidados de todos os idosos
  Future<List<MedicamentoConsolidado>> obterMedicamentosConsolidados(
    String organizacaoId,
  ) async {
    try {
      // Buscar idosos da organização
      final idosoService = IdosoOrganizacaoService();
      final idosos = await idosoService.listarIdosos(organizacaoId);

      if (idosos.isEmpty) return [];

      final idososIds = idosos.map((i) => i.perfilId).toList();

      // Buscar medicamentos de todos os idosos
      final response = await _client
          .from('medicamentos')
          .select()
          .inFilter('perfil_id', idososIds)
          .order('created_at', ascending: false);

      final medicamentos = (response as List)
          .map((m) => Medicamento.fromMap(m as Map<String, dynamic>))
          .toList();

      // Criar mapa de idosos por perfil_id para lookup rápido
      final idososMap = {
        for (var idoso in idosos) idoso.perfilId: idoso
      };

      // Consolidar medicamentos com informações do idoso
      return medicamentos.map((med) {
        final idoso = idososMap[med.perfilId];
        return MedicamentoConsolidado(
          medicamento: med,
          idosoId: med.perfilId,
          idosoNome: idoso?.nomePerfil ?? 'Sem nome',
          quarto: idoso?.quarto,
          setor: idoso?.setor,
        );
      }).toList();
    } on SocketException {
      throw Exception(
          'Erro de conexão. Verifique sua internet e tente novamente.');
    } catch (e) {
      throw Exception('Erro ao obter medicamentos consolidados: $e');
    }
  }

  /// Obter rotinas consolidadas de todos os idosos
  Future<List<RotinaConsolidada>> obterRotinasConsolidadas(
    String organizacaoId,
  ) async {
    try {
      // Buscar idosos da organização
      final idosoService = IdosoOrganizacaoService();
      final idosos = await idosoService.listarIdosos(organizacaoId);

      if (idosos.isEmpty) return [];

      final idososIds = idosos.map((i) => i.perfilId).toList();

      // Buscar rotinas de todos os idosos
      final response = await _client
          .from('rotinas')
          .select()
          .inFilter('perfil_id', idososIds)
          .order('created_at', ascending: false);

      final rotinas = List<Map<String, dynamic>>.from(response);

      // Criar mapa de idosos por perfil_id para lookup rápido
      final idososMap = {
        for (var idoso in idosos) idoso.perfilId: idoso
      };

      // Consolidar rotinas com informações do idoso
      return rotinas.map((rotina) {
        final perfilId = rotina['perfil_id'] as String;
        final idoso = idososMap[perfilId];
        return RotinaConsolidada(
          rotina: rotina,
          idosoId: perfilId,
          idosoNome: idoso?.nomePerfil ?? 'Sem nome',
          quarto: idoso?.quarto,
          setor: idoso?.setor,
        );
      }).toList();
    } on SocketException {
      throw Exception(
          'Erro de conexão. Verifique sua internet e tente novamente.');
    } catch (e) {
      throw Exception('Erro ao obter rotinas consolidadas: $e');
    }
  }

  /// Obter compromissos consolidados de todos os idosos
  Future<List<CompromissoConsolidado>> obterCompromissosConsolidadas(
    String organizacaoId,
  ) async {
    try {
      // Buscar idosos da organização
      final idosoService = IdosoOrganizacaoService();
      final idosos = await idosoService.listarIdosos(organizacaoId);

      if (idosos.isEmpty) return [];

      final idososIds = idosos.map((i) => i.perfilId).toList();

      // Buscar compromissos de todos os idosos
      final response = await _client
          .from('compromissos')
          .select()
          .inFilter('perfil_id', idososIds)
          .order('data_compromisso', ascending: false);

      final compromissos = List<Map<String, dynamic>>.from(response);

      // Criar mapa de idosos por perfil_id para lookup rápido
      final idososMap = {
        for (var idoso in idosos) idoso.perfilId: idoso
      };

      // Consolidar compromissos com informações do idoso
      return compromissos.map((compromisso) {
        final perfilId = compromisso['perfil_id'] as String;
        final idoso = idososMap[perfilId];
        return CompromissoConsolidado(
          compromisso: compromisso,
          idosoId: perfilId,
          idosoNome: idoso?.nomePerfil ?? 'Sem nome',
          quarto: idoso?.quarto,
          setor: idoso?.setor,
        );
      }).toList();
    } on SocketException {
      throw Exception(
          'Erro de conexão. Verifique sua internet e tente novamente.');
    } catch (e) {
      throw Exception('Erro ao obter compromissos consolidados: $e');
    }
  }

  /// Verificar quais medicamentos já foram tomados hoje
  Future<Map<int, bool>> checkMedicamentosConcluidosHoje(
    String perfilId,
    List<int> medicamentoIds,
  ) async {
    try {
      return await HistoricoEventosService.checkMedicamentosConcluidosHoje(
        perfilId,
        medicamentoIds,
      );
    } catch (e) {
      debugPrint('Erro no ConsolidadoOrganizacaoService: $e');
      return {};
    }
  }
}

