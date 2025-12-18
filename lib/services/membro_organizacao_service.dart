import 'package:supabase_flutter/supabase_flutter.dart';
import 'organizacao_service.dart';
import 'supabase_service.dart';

/// Serviço para gerenciar membros da organização
class MembroOrganizacaoService {
  final SupabaseService _supabaseService;

  MembroOrganizacaoService(this._supabaseService);

  /// Listar membros da organização
  Future<List<MembroOrganizacao>> listarMembros(String organizacaoId) async {
    try {
      final response = await Supabase.instance.client
          .from('membros_organizacao')
          .select('*, perfil:perfis(nome, email)')
          .eq('organizacao_id', organizacaoId)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => MembroOrganizacao.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erro ao listar membros: $e');
    }
  }

  /// Convidar membro para organização
  Future<Map<String, dynamic>> convidarMembro({
    required String organizacaoId,
    required String email,
    required String role, // 'admin', 'medico', 'enfermeiro', 'cuidador', 'recepcionista'
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'convidar-membro-organizacao',
        body: {
          'organizacao_id': organizacaoId,
          'email': email,
          'role': role,
        },
      );

      if (response.status != 200) {
        final error = response.data as Map<String, dynamic>?;
        throw Exception(error?['error'] ?? 'Erro ao convidar membro');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Erro ao convidar membro: $e');
    }
  }

  /// Atualizar role do membro
  Future<void> atualizarRole({
    required String membroId,
    required String role,
  }) async {
    try {
      await Supabase.instance.client
          .from('membros_organizacao')
          .update({'role': role})
          .eq('id', membroId);
    } catch (e) {
      throw Exception('Erro ao atualizar role: $e');
    }
  }

  /// Ativar/Desativar membro
  Future<void> atualizarStatus({
    required String membroId,
    required bool ativo,
  }) async {
    try {
      await Supabase.instance.client
          .from('membros_organizacao')
          .update({'ativo': ativo})
          .eq('id', membroId);
    } catch (e) {
      throw Exception('Erro ao atualizar status: $e');
    }
  }

  /// Remover membro
  Future<void> removerMembro(String membroId) async {
    try {
      await Supabase.instance.client
          .from('membros_organizacao')
          .delete()
          .eq('id', membroId);
    } catch (e) {
      throw Exception('Erro ao remover membro: $e');
    }
  }

  /// Verificar permissões
  bool podeGerenciarMembros(String role) {
    return role == 'admin';
  }

  bool podeGerenciarIdosos(String role) {
    return ['admin', 'medico', 'enfermeiro'].contains(role);
  }

  bool podeConfirmarEventos(String role) {
    return ['admin', 'medico', 'enfermeiro', 'cuidador'].contains(role);
  }

  bool podeGerenciarCompromissos(String role) {
    return ['admin', 'medico', 'enfermeiro', 'recepcionista'].contains(role);
  }
}

