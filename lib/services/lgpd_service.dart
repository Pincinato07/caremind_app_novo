import 'dart:convert';
import '../services/supabase_service.dart';
import '../services/medicamento_service.dart';
import '../services/compromisso_service.dart';
import '../models/perfil.dart';
import '../models/medicamento.dart';

/// Serviço para conformidade LGPD
/// Permite exportar e excluir dados do usuário
class LgpdService {
  final SupabaseService _supabaseService;
  final MedicamentoService _medicamentoService;
  final CompromissoService _compromissoService;

  LgpdService(
    this._supabaseService,
    this._medicamentoService,
    this._compromissoService,
  );

  /// Exportar todos os dados do usuário em formato JSON
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    if (userId.isEmpty) {
      throw Exception('ID do usuário não pode estar vazio');
    }

    try {
      // Buscar perfil com tratamento de erro específico
      Perfil? perfil;
      try {
        perfil = await _supabaseService.getProfile(userId);
      } catch (e) {
        throw Exception('Erro ao buscar perfil do usuário: $e');
      }

      // Buscar medicamentos com tratamento de erro específico
      List<Medicamento> medicamentos = [];
      try {
        final medicamentosResult =
            await _medicamentoService.getMedicamentos(userId);
        medicamentos = medicamentosResult.when(
          success: (data) => data,
          failure: (exception) {
            throw Exception(
                'Erro ao buscar medicamentos: ${exception.message}');
          },
        );
      } catch (e) {
        // Log do erro mas continua a exportação
        print('⚠️ Aviso: Erro ao buscar medicamentos: $e');
        // Continua sem medicamentos ao invés de falhar completamente
      }

      // Buscar compromissos com tratamento de erro específico
      List compromissos = [];
      try {
        compromissos = await _compromissoService.getCompromissos(userId);
      } catch (e) {
        // Log do erro mas continua a exportação
        print('⚠️ Aviso: Erro ao buscar compromissos: $e');
        // Continua sem compromissos ao invés de falhar completamente
      }

      // Montar estrutura de dados
      final data = {
        'exportado_em': DateTime.now().toIso8601String(),
        'usuario': {
          'id': userId,
          'user_id': userId,
          'nome': perfil?.nome ?? 'Não informado',
          'tipo': perfil?.tipo ?? 'Não informado',
          'telefone': perfil?.telefone ?? 'Não informado',
          'timezone': perfil?.timezone ?? 'Não informado',
          'criado_em': perfil?.createdAt.toIso8601String() ?? 'Não informado',
        },
        'medicamentos': medicamentos.map((m) => m.toMap()).toList(),
        'compromissos': compromissos,
        'estatisticas': {
          'total_medicamentos': medicamentos.length,
          'total_compromissos': compromissos.length,
        },
        'nota_legal':
            'Dados exportados conforme LGPD - Lei Geral de Proteção de Dados',
      };

      return data;
    } catch (e) {
      // Re-throw se já for uma Exception com mensagem específica
      if (e is Exception && e.toString().contains('Erro ao buscar')) {
        rethrow;
      }
      throw Exception('Erro ao exportar dados: $e');
    }
  }

  /// Exportar dados em formato JSON string
  Future<String> exportUserDataAsJson(String userId) async {
    try {
      final data = await exportUserData(userId);

      // Validar se há dados para exportar
      if (data.isEmpty) {
        throw Exception('Nenhum dado encontrado para exportar');
      }

      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(data);

      // Validar se o JSON foi gerado corretamente
      if (jsonString.isEmpty) {
        throw Exception('Erro ao gerar arquivo JSON');
      }

      return jsonString;
    } catch (e) {
      // Re-throw com mensagem mais clara
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Erro ao converter dados para JSON: $e');
    }
  }

  /// Excluir todos os dados do usuário (Direito ao Esquecimento)
  Future<void> deleteUserData(String userId) async {
    try {
      // Deletar medicamentos
      final medicamentosResult =
          await _medicamentoService.getMedicamentos(userId);
      final medicamentos = medicamentosResult.when(
        success: (data) => data,
        failure: (exception) {
          throw Exception('Erro ao buscar medicamentos: ${exception.message}');
        },
      );
      for (final medicamento in medicamentos) {
        if (medicamento.id != null) {
          await _medicamentoService.deleteMedicamento(medicamento.id!);
        }
      }

      // Deletar compromissos
      final compromissos = await _compromissoService.getCompromissos(userId);
      for (final compromisso in compromissos) {
        final id = compromisso['id'];
        if (id != null) {
          await _compromissoService.deleteCompromisso(id.toString());
        }
      }

      // Nota: A exclusão da conta do usuário (auth.users) deve ser feita através do Supabase Auth
      // Você pode criar uma Edge Function no Supabase para isso
    } catch (e) {
      throw Exception('Erro ao excluir dados: $e');
    }
  }
}
