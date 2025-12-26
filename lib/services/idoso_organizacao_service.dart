import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'organizacao_service.dart';
import '../core/errors/result.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';

/// Serviço para gerenciar idosos da organização
///
/// REFATORADO: Usa Result<T> em vez de throw Exception, erros estruturados do backend
class IdosoOrganizacaoService {
  IdosoOrganizacaoService();

  /// Listar idosos da organização
  Future<List<IdosoOrganizacao>> listarIdosos(String organizacaoId) async {
    try {
      if (organizacaoId.isEmpty) {
        throw Exception('ID da organização não pode estar vazio');
      }

      final response = await Supabase.instance.client
          .from('idosos_organizacao')
          .select(
              '*, perfil:perfis(nome, telefone, data_nascimento, is_virtual)')
          .eq('organizacao_id', organizacaoId)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map(
              (json) => IdosoOrganizacao.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST301' || e.code == 'PGRST116') {
        throw Exception('Organização não encontrada ou sem permissão');
      }
      throw Exception('Erro ao buscar idosos: ${e.message}');
    } on SocketException {
      throw Exception(
          'Erro de conexão. Verifique sua internet e tente novamente.');
    } catch (e) {
      throw Exception('Erro ao listar idosos: ${e.toString()}');
    }
  }

  /// Adicionar idoso virtual à organização
  /// Retorna Map com 'idoso' se sucesso, ou 'duplicado' se idoso já existe
  Future<Map<String, dynamic>> adicionarIdoso({
    required String organizacaoId,
    required String nome,
    String? telefone,
    DateTime? dataNascimento,
    String? quarto,
    String? setor,
    String? observacoes,
  }) async {
    try {
      // VALIDAÇÃO DE DUPLICIDADE: Verificar se já existe idoso com mesmo nome + data_nascimento
      if (dataNascimento != null) {
        final nomeNormalizado = nome.trim().toLowerCase();
        final dataFormatada = dataNascimento
            .toIso8601String()
            .split('T')[0]; // Apenas data, sem hora

        final duplicadosResponse = await Supabase.instance.client
            .from('perfis')
            .select('''
              id, 
              nome, 
              data_nascimento, 
              organizacao_id,
              idosos_organizacao(organizacao_id)
            ''')
            .eq('tipo', 'idoso')
            .ilike('nome', nomeNormalizado)
            .eq('data_nascimento', dataFormatada);

        if (duplicadosResponse.isNotEmpty) {
          // Verificar se algum está em uma organização
          for (final idoso in duplicadosResponse) {
            String? orgId = idoso['organizacao_id'] as String?;

            // Se não tem organizacao_id direto, verificar via idosos_organizacao
            if (orgId == null && idoso['idosos_organizacao'] != null) {
              final idososOrg = idoso['idosos_organizacao'] as List;
              if (idososOrg.isNotEmpty) {
                orgId = idososOrg[0]['organizacao_id'] as String?;
              }
            }

            if (orgId != null) {
              // Buscar nome da organização
              final orgResponse = await Supabase.instance.client
                  .from('organizacoes')
                  .select('nome')
                  .eq('id', orgId)
                  .maybeSingle();

              final nomeOrg =
                  orgResponse?['nome'] as String? ?? 'uma organização';

              return {
                'duplicado': {
                  'id': idoso['id'],
                  'nome': idoso['nome'],
                  'data_nascimento': idoso['data_nascimento'],
                  'organizacao_id': orgId,
                  'organizacao_nome': nomeOrg,
                }
              };
            }
          }
        }
      }

      // Criar perfil virtual
      final perfilId = DateTime.now().millisecondsSinceEpoch.toString();

      await Supabase.instance.client
          .from('perfis')
          .insert({
            'id': perfilId,
            'nome': nome,
            'telefone': telefone,
            'data_nascimento': dataNascimento?.toIso8601String().split('T')[0],
            'tipo': 'idoso',
            'is_virtual': true,
            'user_id': null,
            'organizacao_id': organizacaoId,
          })
          .select()
          .single();

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
          .select(
              '*, perfil:perfis(nome, telefone, data_nascimento, is_virtual)')
          .single();

      return {'idoso': IdosoOrganizacao.fromJson(idosoOrgResponse)};
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('Já existe um idoso com estes dados nesta organização');
      } else if (e.code == 'PGRST301' || e.code == 'PGRST116') {
        throw Exception('Organização não encontrada ou sem permissão');
      }
      throw Exception('Erro ao adicionar idoso: ${e.message}');
    } on SocketException {
      throw Exception(
          'Erro de conexão. Verifique sua internet e tente novamente.');
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('duplicado') || errorMsg.contains('já existe')) {
        rethrow;
      }
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

      final idoso = idosoResponse;
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
          .select(
              '*, perfil:perfis(nome, telefone, data_nascimento, is_virtual)')
          .eq('id', idosoId)
          .single();

      return IdosoOrganizacao.fromJson(idosoAtualizadoResponse);
    } catch (e) {
      throw Exception('Erro ao atualizar idoso: $e');
    }
  }

  /// Reivindicar perfil virtual (claim profile)
  ///
  /// REFATORADO: Retorna Result<T>, processa erros estruturados do backend
  Future<Result<Map<String, dynamic>>> claimProfile({
    required String perfilId,
    required String action, // 'convert' ou 'link_family'
    String? codigoVinculacao,
    String? telefone,
  }) async {
    try {
      final body = <String, dynamic>{
        'perfil_id': perfilId,
        'action': action,
      };

      if (codigoVinculacao != null) {
        body['codigo_vinculacao'] = codigoVinculacao;
      }

      // Telefone obrigatório para SOS
      if (telefone != null && telefone.trim().isNotEmpty) {
        body['telefone'] = telefone.trim();
      }

      final response = await Supabase.instance.client.functions.invoke(
        'claim-profile',
        body: body,
      );

      // Sucesso
      if (response.status == 200) {
        return Success(response.data as Map<String, dynamic>);
      }

      // Erro estruturado do backend
      if (response.data is Map<String, dynamic>) {
        final errorData = response.data as Map<String, dynamic>;
        final exception = ErrorHandler.fromStructuredError(errorData);
        return Failure(exception);
      }

      // Erro sem estrutura (fallback)
      return Failure(UnknownException(
        message: 'Erro ao reivindicar perfil',
        code: response.status.toString(),
        originalError: response.data,
      ));
    } on SocketException catch (e) {
      return Failure(NetworkException(
        message: 'Erro de conexão. Verifique sua internet e tente novamente.',
        originalError: e,
      ));
    } on FunctionException catch (e) {
      // FunctionException do Supabase
      try {
        // Tentar parsear como JSON estruturado
        if (e.details != null && e.details is Map) {
          final errorData = e.details as Map<String, dynamic>;
          final exception = ErrorHandler.fromStructuredError(errorData);
          return Failure(exception);
        }
      } catch (_) {
        // Fallback para mensagem genérica
      }

      return Failure(DatabaseException(
        message: 'Erro ao reivindicar perfil: ${e.toString()}',
        code: e.status.toString(),
        originalError: e,
      ));
    } catch (e) {
      return Failure(ErrorHandler.toAppException(e));
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

      final idoso = idosoResponse;
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

        final perfil = perfilResponse;
        if (perfil['is_virtual'] == true) {
          await Supabase.instance.client
              .from('perfis')
              .delete()
              .eq('id', perfilId);
        }
      } catch (e) {
        // Ignorar erro se perfil não existir
      }
    } catch (e) {
      throw Exception('Erro ao remover idoso: $e');
    }
  }
}
