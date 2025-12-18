import 'package:supabase_flutter/supabase_flutter.dart';
import 'organizacao_service.dart';
import 'supabase_service.dart';

/// Serviço para gerenciar idosos da organização
class IdosoOrganizacaoService {
  final SupabaseService _supabaseService;

  IdosoOrganizacaoService(this._supabaseService);

  /// Listar idosos da organização
  Future<List<IdosoOrganizacao>> listarIdosos(String organizacaoId) async {
    try {
      final response = await Supabase.instance.client
          .from('idosos_organizacao')
          .select('*, perfil:perfis(nome, telefone, data_nascimento, is_virtual)')
          .eq('organizacao_id', organizacaoId)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => IdosoOrganizacao.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erro ao listar idosos: $e');
    }
  }

  /// Adicionar idoso virtual à organização
  Future<IdosoOrganizacao> adicionarIdoso({
    required String organizacaoId,
    required String nome,
    String? telefone,
    DateTime? dataNascimento,
    String? quarto,
    String? setor,
    String? observacoes,
  }) async {
    try {
      // Criar perfil virtual
      final perfilId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final perfilResponse = await Supabase.instance.client
          .from('perfis')
          .insert({
            'id': perfilId,
            'nome': nome,
            'telefone': telefone,
            'data_nascimento': dataNascimento?.toIso8601String(),
            'tipo': 'idoso',
            'is_virtual': true,
            'user_id': null,
            'organizacao_id': organizacaoId,
          })
          .select()
          .single();

      if (perfilResponse == null) {
        throw Exception('Erro ao criar perfil virtual');
      }

      // Vincular à organização
      final idosoOrgResponse = await Supabase.instance.client
          .from('idosos_organizacao')
          .insert({
            'organizacao_id': organizacaoId,
            'perfil_id': perfilId,
            'quarto': quarto,
            'setor': setor,
            'observacoes': observacoes,
          })
          .select('*, perfil:perfis(nome, telefone, data_nascimento, is_virtual)')
          .single();

      if (idosoOrgResponse == null) {
        throw Exception('Erro ao vincular idoso à organização');
      }

      return IdosoOrganizacao.fromJson(idosoOrgResponse as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erro ao adicionar idoso: $e');
    }
  }

  /// Importar idosos em massa via CSV
  Future<Map<String, dynamic>> importarIdososCSV({
    required String organizacaoId,
    required List<Map<String, dynamic>> idosos,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'importar-idosos-csv',
        body: {
          'organizacao_id': organizacaoId,
          'idosos': idosos,
        },
      );

      if (response.status != 200) {
        final error = response.data as Map<String, dynamic>?;
        throw Exception(error?['error'] ?? 'Erro ao importar idosos');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Erro ao importar idosos: $e');
    }
  }

  /// Atualizar idoso
  Future<IdosoOrganizacao> atualizarIdoso({
    required String idosoId,
    String? nome,
    String? telefone,
    DateTime? dataNascimento,
    String? quarto,
    String? setor,
    String? observacoes,
  }) async {
    try {
      // Buscar idoso para obter perfil_id
      final idosoResponse = await Supabase.instance.client
          .from('idosos_organizacao')
          .select('perfil_id')
          .eq('id', idosoId)
          .single();

      if (idosoResponse == null) {
        throw Exception('Idoso não encontrado');
      }

      final idoso = idosoResponse as Map<String, dynamic>;
      final perfilId = idoso['perfil_id'] as String;

      // Atualizar perfil
      final perfilUpdates = <String, dynamic>{};
      if (nome != null) perfilUpdates['nome'] = nome;
      if (telefone != null) perfilUpdates['telefone'] = telefone;
      if (dataNascimento != null) {
        perfilUpdates['data_nascimento'] = dataNascimento.toIso8601String();
      }

      if (perfilUpdates.isNotEmpty) {
        await Supabase.instance.client
            .from('perfis')
            .update(perfilUpdates)
            .eq('id', perfilId);
      }

      // Atualizar vínculo com organização
      final orgUpdates = <String, dynamic>{};
      if (quarto != null) orgUpdates['quarto'] = quarto;
      if (setor != null) orgUpdates['setor'] = setor;
      if (observacoes != null) orgUpdates['observacoes'] = observacoes;

      if (orgUpdates.isNotEmpty) {
        await Supabase.instance.client
            .from('idosos_organizacao')
            .update(orgUpdates)
            .eq('id', idosoId);
      }

      // Buscar idoso atualizado
      final idosoAtualizadoResponse = await Supabase.instance.client
          .from('idosos_organizacao')
          .select('*, perfil:perfis(nome, telefone, data_nascimento, is_virtual)')
          .eq('id', idosoId)
          .single();

      if (idosoAtualizadoResponse == null) {
        throw Exception('Erro ao buscar idoso atualizado');
      }

      return IdosoOrganizacao.fromJson(idosoAtualizadoResponse as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erro ao atualizar idoso: $e');
    }
  }

  /// Reivindicar perfil virtual (claim profile)
  Future<Map<String, dynamic>> claimProfile({
    required String perfilId,
    required String action, // 'convert' ou 'link_family'
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'claim-profile',
        body: {
          'perfil_id': perfilId,
          'action': action,
        },
      );

      if (response.status != 200) {
        final error = response.data as Map<String, dynamic>?;
        throw Exception(error?['error'] ?? error?['message'] ?? 'Erro ao reivindicar perfil');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Erro ao reivindicar perfil: $e');
    }
  }

  /// Remover idoso da organização
  Future<void> removerIdoso(String idosoId) async {
    try {
      // Buscar perfil_id
      final idosoResponse = await Supabase.instance.client
          .from('idosos_organizacao')
          .select('perfil_id')
          .eq('id', idosoId)
          .single();

      if (idosoResponse == null) {
        throw Exception('Idoso não encontrado');
      }

      final idoso = idosoResponse as Map<String, dynamic>;
      final perfilId = idoso['perfil_id'] as String;

      // Remover vínculo
      await Supabase.instance.client
          .from('idosos_organizacao')
          .delete()
          .eq('id', idosoId);

      // Se for perfil virtual, remover também
      try {
        final perfilResponse = await Supabase.instance.client
            .from('perfis')
            .select('is_virtual')
            .eq('id', perfilId)
            .single();

        if (perfilResponse != null) {
          final perfil = perfilResponse as Map<String, dynamic>;
          if (perfil['is_virtual'] == true) {
            await Supabase.instance.client
                .from('perfis')
                .delete()
                .eq('id', perfilId);
          }
        }
      } catch (e) {
        // Ignorar erro se perfil não existir
      }
    } catch (e) {
      throw Exception('Erro ao remover idoso: $e');
    }
  }
}

