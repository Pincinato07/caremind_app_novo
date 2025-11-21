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
}

