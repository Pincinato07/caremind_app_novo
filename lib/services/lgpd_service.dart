import 'dart:convert';
import '../services/supabase_service.dart';
import '../services/medicamento_service.dart';
import '../services/compromisso_service.dart';
import '../core/injection/injection.dart';

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
    try {
      // Buscar perfil
      final perfil = await _supabaseService.getProfile(userId);

      // Buscar medicamentos
      final medicamentos = await _medicamentoService.getMedicamentos(userId);

      // Buscar compromissos
      final compromissos = await _compromissoService.getCompromissos(userId);

      // Montar estrutura de dados
      final data = {
        'exportado_em': DateTime.now().toIso8601String(),
        'usuario': {
          'id': userId,
          'email': perfil?.email ?? '',
          'nome': perfil?.nome ?? '',
          'tipo': perfil?.tipo ?? '',
          'criado_em': perfil?.createdAt.toIso8601String() ?? '',
        },
        'medicamentos': medicamentos.map((m) => m.toMap()).toList(),
        'compromissos': compromissos,
        'nota_legal': 'Dados exportados conforme LGPD - Lei Geral de Proteção de Dados',
      };

      return data;
    } catch (e) {
      throw Exception('Erro ao exportar dados: $e');
    }
  }

  /// Exportar dados em formato JSON string
  Future<String> exportUserDataAsJson(String userId) async {
    final data = await exportUserData(userId);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  /// Excluir todos os dados do usuário (Direito ao Esquecimento)
  Future<void> deleteUserData(String userId) async {
    try {
      // Deletar medicamentos
      final medicamentos = await _medicamentoService.getMedicamentos(userId);
      for (final medicamento in medicamentos) {
        if (medicamento.id != null) {
          await _medicamentoService.deleteMedicamento(medicamento.id!);
        }
      }

      // Deletar compromissos
      final compromissos = await _compromissoService.getCompromissos(userId);
      for (final compromisso in compromissos) {
        final id = compromisso['id'] as int?;
        if (id != null) {
          await _compromissoService.deleteCompromisso(id);
        }
      }

      // Nota: A exclusão da conta do usuário (auth.users) deve ser feita através do Supabase Auth
      // Você pode criar uma Edge Function no Supabase para isso
    } catch (e) {
      throw Exception('Erro ao excluir dados: $e');
    }
  }
}

