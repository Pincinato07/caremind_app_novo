import 'package:supabase_flutter/supabase_flutter.dart';
import 'organizacao_service.dart';
import '../core/injection/injection.dart';

/// Helper para validar acesso a dados de organizações
class OrganizacaoValidator {
  final SupabaseClient _client = Supabase.instance.client;
  final OrganizacaoService _organizacaoService = getIt<OrganizacaoService>();

  /// Valida se o usuário atual é membro da organização do idoso
  /// Retorna o organizacaoId se válido, lança exceção se não for membro
  /// Se idoso não pertence a organização, lança exceção específica
  Future<String> validarAcessoIdosoOrganizacao(String perfilId) async {
    try {
      // Buscar organizacao_id do idoso
      final idosoOrgResponse = await _client
          .from('idosos_organizacao')
          .select('organizacao_id')
          .eq('perfil_id', perfilId)
          .eq('ativo', true)
          .maybeSingle();

      if (idosoOrgResponse == null) {
        // Idoso não pertence a organização - isso é OK para modo individual
        // Mas este método é específico para validar acesso organizacional
        throw Exception('Idoso não pertence a nenhuma organização (modo individual)');
      }

      final organizacaoId = idosoOrgResponse['organizacao_id'] as String?;
      if (organizacaoId == null) {
        throw Exception('Organização não encontrada para este idoso');
      }

      // VALIDAR: Usuário é membro dessa organização?
      final isMembro = await _organizacaoService.isMembroOrganizacao(organizacaoId);
      if (!isMembro) {
        throw Exception('Acesso negado: você não é membro da organização deste idoso');
      }

      return organizacaoId;
    } catch (e) {
      // Se já é uma Exception, re-lançar
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Erro ao validar acesso: $e');
    }
  }

  /// Valida se o usuário pode acessar dados de um idoso
  /// Retorna true se pode acessar (individual ou membro da organização)
  Future<bool> podeAcessarIdoso(String perfilId) async {
    try {
      // Verificar se idoso pertence a organização
      final idosoOrgResponse = await _client
          .from('idosos_organizacao')
          .select('organizacao_id')
          .eq('perfil_id', perfilId)
          .eq('ativo', true)
          .maybeSingle();

      if (idosoOrgResponse == null) {
        // Idoso não pertence a organização, acesso permitido (modo individual)
        return true;
      }

      final organizacaoId = idosoOrgResponse['organizacao_id'] as String?;
      if (organizacaoId == null) {
        return false;
      }

      // Se pertence a organização, verificar se usuário é membro
      return await _organizacaoService.isMembroOrganizacao(organizacaoId);
    } catch (e) {
      return false;
    }
  }

  /// Valida se o usuário pode gerenciar dados de um idoso
  /// Verifica se é membro E tem permissão adequada
  Future<bool> podeGerenciarIdoso(String perfilId, {String? roleMinimo}) async {
    try {
      final organizacaoId = await validarAcessoIdosoOrganizacao(perfilId);
      
      if (roleMinimo == null) {
        // Apenas verificar se é membro (já validado acima)
        return true;
      }

      // Verificar role do usuário
      final role = await _organizacaoService.obterRoleOrganizacao(organizacaoId);
      if (role == null) {
        return false;
      }

      // Hierarquia de roles
      const roleHierarchy = {
        'recepcionista': 1,
        'cuidador': 2,
        'enfermeiro': 3,
        'medico': 4,
        'admin': 5,
      };

      final userLevel = roleHierarchy[role] ?? 0;
      final requiredLevel = roleHierarchy[roleMinimo] ?? 0;

      return userLevel >= requiredLevel;
    } catch (e) {
      // Se não é membro ou não pertence a organização, retornar false
      return false;
    }
  }
}

