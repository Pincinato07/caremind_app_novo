import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';
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
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST301' || e.code == 'PGRST116') {
        throw Exception('Organização não encontrada ou sem permissão');
      }
      throw Exception('Erro ao buscar membros: ${e.message ?? e.toString()}');
    } on SocketException catch (e) {
      throw Exception('Erro de conexão. Verifique sua internet e tente novamente.');
    } catch (e) {
      throw Exception('Erro ao listar membros: ${e.toString()}');
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
  /// Retorna true se o usuário atual foi removido (precisa redirecionar)
  Future<bool> removerMembro(String membroId) async {
    try {
      // Obter user_id atual antes de remover
      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentUserId = currentUser?.id;
      
      // Buscar perfil_id do membro que será removido
      final membroResponse = await Supabase.instance.client
          .from('membros_organizacao')
          .select('perfil_id')
          .eq('id', membroId)
          .single();
      
      if (membroResponse == null) {
        throw Exception('Membro não encontrado');
      }
      
      final perfilIdRemovido = membroResponse['perfil_id'] as String;
      
      // Verificar se é o próprio usuário que está sendo removido
      final perfilAtualResponse = await Supabase.instance.client
          .from('perfis')
          .select('id')
          .eq('user_id', currentUserId)
          .maybeSingle();
      
      final perfilAtualId = perfilAtualResponse?['id'] as String?;
      final usuarioFoiRemovido = perfilAtualId == perfilIdRemovido;
      
      // Remover membro
      await Supabase.instance.client
          .from('membros_organizacao')
          .delete()
          .eq('id', membroId);
      
      // Se o usuário atual foi removido, verificar se ainda é membro de outra organização
      if (usuarioFoiRemovido && currentUserId != null && perfilAtualId != null) {
        final outrasOrganizacoes = await Supabase.instance.client
            .from('membros_organizacao')
            .select('id')
            .eq('perfil_id', perfilAtualId)
            .eq('ativo', true)
            .limit(1);
        
        // Se não é membro de nenhuma organização, precisa redirecionar
        if (outrasOrganizacoes.isEmpty) {
          return true; // Indica que precisa redirecionar
        }
      }
      
      return false; // Não precisa redirecionar
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST301' || e.code == 'PGRST116') {
        throw Exception('Membro não encontrado ou sem permissão');
      }
      throw Exception('Erro ao remover membro: ${e.message ?? e.toString()}');
    } on SocketException catch (e) {
      throw Exception('Erro de conexão. Verifique sua internet e tente novamente.');
    } catch (e) {
      throw Exception('Erro ao remover membro: ${e.toString()}');
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

