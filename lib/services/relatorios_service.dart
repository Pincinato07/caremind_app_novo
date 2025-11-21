import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';
import '../core/errors/app_exception.dart';

class RelatoriosService {
  final SupabaseClient _client;

  RelatoriosService(this._client);

  /// Busca histórico de eventos usando a Edge Function relatorios-historico
  /// 
  /// [perfilId] - ID do perfil para buscar histórico
  /// [dataInicio] - Data de início no formato ISO (YYYY-MM-DD)
  /// [dataFim] - Data de fim no formato ISO (YYYY-MM-DD)
  /// [mode] - Modo: "list" para lista de eventos ou "analytics" para dados analíticos
  Future<Map<String, dynamic>> getRelatorioHistorico({
    required String perfilId,
    required String dataInicio,
    required String dataFim,
    String mode = 'list',
  }) async {
    try {
      // Obter token de autenticação
      final session = _client.auth.currentSession;
      if (session == null) {
        throw Exception('Usuário não autenticado');
      }

      // Chamar Edge Function
      final response = await _client.functions.invoke(
        'relatorios-historico',
        body: {
          'perfil_id': perfilId,
          'data_inicio': dataInicio,
          'data_fim': dataFim,
          'mode': mode,
        },
      );

      // Verificar se houve erro na resposta
      if (response.data != null) {
        // A resposta pode ser uma lista (mode='list') ou um Map (mode='analytics')
        if (response.data is List) {
          // Retornar lista diretamente em um Map com chave 'data'
          return {'data': response.data};
        } else if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          // Verificar se há erro na resposta
          if (data.containsKey('error')) {
            final errorMsg = data['error'] as String? ?? 'Erro desconhecido';
            throw Exception(errorMsg);
          }
          
          // Retornar os dados
          return data;
        }
      }

      // Verificar se há erro HTTP
      if (response.status >= 400) {
        final errorMsg = response.data is Map<String, dynamic>
            ? (response.data as Map<String, dynamic>)['error'] as String?
            : 'Erro ao buscar relatório (status: ${response.status})';
        throw Exception(errorMsg ?? 'Erro ao buscar relatório');
      }

      // Se chegou aqui, pode ser que a resposta não tenha o formato esperado
      throw Exception('Resposta inválida da Edge Function');
    } catch (error) {
      // Re-throw se já for uma AppException, senão converter
      if (error is AppException) {
        rethrow;
      }
      throw ErrorHandler.toAppException(error);
    }
  }

  /// Busca alertas recentes
  /// 
  /// [perfilId] - ID do perfil (familiar ou individual)
  /// 
  /// Se for familiar: busca eventos dos idosos vinculados
  /// Se for individual: busca eventos do próprio perfil
  /// 
  /// Retorna lista de eventos críticos ou recentes
  Future<List<Map<String, dynamic>>> getAlertasRecentes(String perfilId) async {
    try {
      List<String> perfisIdsParaBuscar = [];

      // 1. Verificar se é familiar (tem vínculos)
      final vinculosResponse = await _client
          .from('vinculos_familiares')
          .select('id_idoso')
          .eq('id_familiar', perfilId);

      if (vinculosResponse.isNotEmpty) {
        // É familiar: buscar eventos dos idosos vinculados
        for (var vinculo in vinculosResponse) {
          if (vinculo['id_idoso'] != null) {
            perfisIdsParaBuscar.add(vinculo['id_idoso'] as String);
          }
        }
      }

      // Se não encontrou vínculos, é individual: buscar eventos do próprio perfil
      if (perfisIdsParaBuscar.isEmpty) {
        perfisIdsParaBuscar = [perfilId];
      }

      if (perfisIdsParaBuscar.isEmpty) {
        return [];
      }

      // 2. Buscar eventos críticos ou recentes
      // Tipos de eventos críticos
      final tiposCriticos = [
        'medicamento_atrasado',
        'medicamento_nao_tomado',
        'estoque_baixo',
        'rotina_nao_concluida',
        'compromisso_atrasado',
      ];

      // Buscar eventos críticos primeiro
      final eventosCriticosResponse = await _client
          .from('historico_eventos')
          .select()
          .inFilter('perfil_id', perfisIdsParaBuscar)
          .inFilter('tipo_evento', tiposCriticos)
          .order('data_hora', ascending: false)
          .limit(20);

      // Se encontrou eventos críticos, retornar eles
      if (eventosCriticosResponse.isNotEmpty) {
        return List<Map<String, dynamic>>.from(eventosCriticosResponse);
      }

      // Se não encontrou eventos críticos, buscar os últimos eventos gerais
      final eventosGeraisResponse = await _client
          .from('historico_eventos')
          .select()
          .inFilter('perfil_id', perfisIdsParaBuscar)
          .order('data_hora', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(eventosGeraisResponse);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }
}

