import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/perfil.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../core/utils/data_cleaner.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // Getter público para acessar o cliente
  SupabaseClient get client => _client;

  // Authentication methods
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String nome,
    required String tipo,
    String? telefone,
    bool lgpdConsent = false,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': nome,
          'account_type': tipo,
          'phone': telefone,
          'data_sharing_consent': lgpdConsent,
        },
      );

      // Se o usuário foi criado com sucesso, criar perfil e enviar email de boas-vindas
      if (response.user != null) {
        final userId = response.user!.id;

        // Criar perfil na tabela perfis
        try {
          await _client.from('perfis').upsert({
            'user_id': userId,
            'nome': nome,
            'tipo': tipo,
            'telefone': telefone,
            'data_sharing_consent': lgpdConsent,
            'terms_accepted_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');
        } catch (profileError) {
          // Log do erro mas não bloqueia o registro
          print('Erro ao criar perfil (não bloqueante): $profileError');
        }

        // Enviar email de boas-vindas (não bloqueante)
        try {
          await _client.functions.invoke('send-welcome-email', body: {
            'user_id': userId,
            'account_type': tipo,
          });
        } catch (emailError) {
          // Log do erro mas não bloqueia o registro
          print(
              'Erro ao enviar email de boas-vindas (não bloqueante): $emailError');
        }
      }

      return response;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'caremind://auth-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // OAuth abre o navegador, então retornamos true para indicar que iniciou
      return true;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: null, // O Supabase enviará um email com link de redefinição
      );
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Geração de código de vinculação
  Future<String> gerarCodigoVinculacao() async {
    try {
      final response = await _client.rpc('gerar_codigo_vinculacao');
      return response as String;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Vincular por código
  Future<Map<String, dynamic>> vincularPorCodigo(String codigo) async {
    try {
      final response = await _client.rpc(
        'vincular_por_codigo',
        params: {'codigo_input': codigo},
      );
      return response as Map<String, dynamic>;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Criar e vincular idoso usando Edge Function
  Future<Map<String, dynamic>> criarEVincularIdoso({
    required String nome,
    required String email,
    required String senha,
  }) async {
    try {
      // Obter token de autenticação
      final session = _client.auth.currentSession;
      if (session == null) {
        throw Exception('Usuário não autenticado');
      }

      // Chamar Edge Function
      final response = await _client.functions.invoke(
        'criar-idoso',
        body: {
          'nome_idoso': nome,
          'email_idoso': email,
          'senha_idoso': senha,
        },
      );

      // Verificar se houve erro
      if (response.data != null) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && data.containsKey('error')) {
          throw Exception(data['error'] as String);
        }
        if (data != null &&
            data.containsKey('success') &&
            data['success'] == true) {
          return data;
        }
      }

      // Se chegou aqui, pode ser que a resposta não tenha o formato esperado
      throw Exception('Resposta inválida da Edge Function');
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Atualizar idoso usando Edge Function
  Future<Map<String, dynamic>> atualizarIdoso({
    required String idosoId,
    required String nome,
    String? telefone,
    String? dataNascimento,
    String? fotoUsuario,
  }) async {
    try {
      // Obter token de autenticação
      final session = _client.auth.currentSession;
      if (session == null) {
        throw Exception('Usuário não autenticado');
      }

      // Chamar Edge Function
      final response = await _client.functions.invoke(
        'atualizar-idoso',
        body: {
          'idosoId': idosoId,
          'nome': nome,
          if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
          if (dataNascimento != null && dataNascimento.isNotEmpty)
            'data_nascimento': dataNascimento,
          if (fotoUsuario != null && fotoUsuario.isNotEmpty)
            'foto_usuario': fotoUsuario,
        },
      );

      // Verificar se houve erro na resposta
      if (response.data != null) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null) {
          // Verificar se há erro na resposta
          if (data.containsKey('error')) {
            final errorMsg = data['error'] as String? ?? 'Erro desconhecido';
            throw Exception(errorMsg);
          }

          // Verificar se foi bem-sucedido
          if (data.containsKey('success') && data['success'] == true) {
            return data;
          }
        }
      }

      // Verificar se há erro HTTP
      if (response.status >= 400) {
        final errorMsg = response.data is Map<String, dynamic>
            ? (response.data as Map<String, dynamic>)['error'] as String?
            : 'Erro ao atualizar idoso (status: ${response.status})';
        throw Exception(errorMsg ?? 'Erro ao atualizar idoso');
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

  // Profile methods
  Future<Perfil?> getProfile(String userId) async {
    try {
      // Baseado no schema real, a tabela perfis tem:
      // - id (uuid, primary key, referencia auth.users(id))
      // - user_id (uuid, unique, referencia auth.users(id))

      // Primeiro, tentar buscar por user_id (campo correto baseado no schema)
      final response = await _client
          .from('perfis')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return Perfil.fromMap(response);
      }

      // Se não encontrar por user_id, tentar por id (fallback)
      final fallbackResponse =
          await _client.from('perfis').select().eq('id', userId).maybeSingle();

      if (fallbackResponse != null) {
        return Perfil.fromMap(fallbackResponse);
      }

      // Se não encontrar por nenhum dos métodos, tentar usar .or() para compatibilidade
      final orResponse = await _client
          .from('perfis')
          .select()
          .or('user_id.eq.$userId,id.eq.$userId')
          .maybeSingle();

      if (orResponse != null) {
        return Perfil.fromMap(orResponse);
      }

      return null;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? nome,
    String? tipo,
    String? codigoVinculacao,
    String? fotoUsuario,
    DateTime? codigoVinculacaoExpiraEm,
    String? telefone,
    String? timezone,
    bool? dataSharingConsent,
    DateTime? termsAcceptedAt,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (nome != null) updates['nome'] = nome;
      if (tipo != null) updates['tipo'] = tipo;
      if (codigoVinculacao != null) {
        updates['codigo_vinculacao'] = codigoVinculacao;
      }
      if (fotoUsuario != null) updates['foto_usuario'] = fotoUsuario;
      if (codigoVinculacaoExpiraEm != null) {
        updates['codigo_vinculacao_expira_em'] =
            codigoVinculacaoExpiraEm.toIso8601String();
      }
      if (telefone != null) updates['telefone'] = telefone;
      if (timezone != null) updates['timezone'] = timezone;
      if (dataSharingConsent != null)
        updates['data_sharing_consent'] = dataSharingConsent;
      if (termsAcceptedAt != null)
        updates['terms_accepted_at'] = termsAcceptedAt.toIso8601String();

      if (updates.isNotEmpty) {
        // Limpar dados antes de atualizar (remove strings vazias)
        final cleanedUpdates = DataCleaner.cleanData(updates);

        // Baseado no schema, buscar pelo user_id (campo correto)
        final perfilResponse = await _client
            .from('perfis')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        final perfilId = perfilResponse?['id'] as String?;

        // Usar o ID do perfil encontrado, senão usar o userId (fallback)
        final targetId = perfilId ?? userId;

        await _client.from('perfis').update(cleanedUpdates).eq('id', targetId);
      }
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Buscar idosos vinculados a um familiar
  Future<List<Perfil>> getIdososVinculados(String familiarId) async {
    try {
      // Baseado no schema, encontrar o perfil_id do familiar usando user_id
      final familiarPerfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', familiarId)
          .maybeSingle();

      final familiarPerfilId = familiarPerfilResponse?['id'] as String?;

      // Usar perfil_id se encontrado, senão usar familiarId (fallback)
      final targetFamiliarId = familiarPerfilId ?? familiarId;

      // Buscar vínculos
      final vinculosResponse = await _client
          .from('vinculos_familiares')
          .select('id_idoso')
          .eq('id_familiar', targetFamiliarId);

      if (vinculosResponse.isEmpty) {
        return [];
      }

      // Extrair IDs dos idosos
      final List<String> idososIds = [];
      for (var vinculo in vinculosResponse) {
        if (vinculo['id_idoso'] != null) {
          idososIds.add(vinculo['id_idoso'] as String);
        }
      }

      if (idososIds.isEmpty) {
        return [];
      }

      // Buscar perfis dos idosos
      final perfisResponse =
          await _client.from('perfis').select().inFilter('id', idososIds);

      if (perfisResponse.isEmpty) {
        return [];
      }

      return (perfisResponse as List)
          .map((item) => Perfil.fromMap(item))
          .toList();
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Desvincular idoso (remove apenas o vínculo, mantém o idoso)
  Future<void> desvincularIdoso(String idosoId) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Buscar perfil do familiar
      final perfilFamiliar = await getProfile(user.id);
      if (perfilFamiliar == null) {
        throw Exception('Perfil do familiar não encontrado');
      }

      // Remover vínculo usando o ID do perfil do familiar
      await _client
          .from('vinculos_familiares')
          .delete()
          .eq('id_familiar', perfilFamiliar.id)
          .eq('id_idoso', idosoId);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Buscar cuidador principal (familiar vinculado) de um idoso
  Future<Map<String, dynamic>?> getCuidadorPrincipal(String idosoId) async {
    try {
      // Buscar vínculo familiar
      final vinculoResponse = await _client
          .from('vinculos_familiares')
          .select('id_familiar')
          .eq('id_idoso', idosoId)
          .limit(1)
          .maybeSingle();

      if (vinculoResponse == null) {
        return null;
      }

      final familiarId = vinculoResponse['id_familiar'] as String?;
      if (familiarId == null) {
        return null;
      }

      // Buscar perfil do familiar com telefone
      final perfilResponse = await _client
          .from('perfis')
          .select('id, nome, telefone')
          .eq('id', familiarId)
          .maybeSingle();

      if (perfilResponse == null) {
        return null;
      }

      return {
        'id': perfilResponse['id'] as String,
        'nome': perfilResponse['nome'] as String? ?? 'Familiar',
        'telefone': perfilResponse['telefone'] as String?,
      };
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Remover idoso completamente (remove vínculo e perfil)
  // Nota: Isso requer privilégios de admin, então pode precisar de uma Edge Function
  Future<void> removerIdoso(String idosoId) async {
    try {
      // Primeiro desvincular
      await desvincularIdoso(idosoId);

      // Buscar user_id do idoso
      final perfilIdoso = await getProfile(idosoId);
      if (perfilIdoso == null) {
        throw Exception('Perfil do idoso não encontrado');
      }

      // Nota: Para remover o usuário do Auth, seria necessário uma Edge Function
      // Por enquanto, apenas removemos o perfil
      // O vínculo já foi removido acima

      // Remover perfil
      await _client.from('perfis').delete().eq('id', idosoId);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }
}
