import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Constantes de permissões
class Permissoes {
  static const String ORG_VIEW = 'org:view';
  static const String ORG_EDIT = 'org:edit';
  static const String ORG_DELETE = 'org:delete';
  
  static const String MEMBER_VIEW = 'member:view';
  static const String MEMBER_ADD = 'member:add';
  static const String MEMBER_EDIT = 'member:edit';
  static const String MEMBER_REMOVE = 'member:remove';
  
  static const String IDOSO_VIEW = 'idoso:view';
  static const String IDOSO_ADD = 'idoso:add';
  static const String IDOSO_EDIT = 'idoso:edit';
  static const String IDOSO_REMOVE = 'idoso:remove';
  
  static const String DATA_VIEW = 'data:view';
  static const String DATA_EDIT = 'data:edit';
  static const String DATA_DELETE = 'data:delete';
  
  static const String REPORTS_VIEW = 'reports:view';
  static const String ANALYTICS_VIEW = 'analytics:view';
  static const String CONFIG_EDIT = 'config:edit';
  static const String EXPORT_DATA = 'data:export';
}

/// Mapeamento de roles para permissões
const Map<String, List<String>> ROLE_PERMISSIONS = {
  'admin': [
    Permissoes.ORG_VIEW,
    Permissoes.ORG_EDIT,
    Permissoes.ORG_DELETE,
    Permissoes.MEMBER_VIEW,
    Permissoes.MEMBER_ADD,
    Permissoes.MEMBER_EDIT,
    Permissoes.MEMBER_REMOVE,
    Permissoes.IDOSO_VIEW,
    Permissoes.IDOSO_ADD,
    Permissoes.IDOSO_EDIT,
    Permissoes.IDOSO_REMOVE,
    Permissoes.DATA_VIEW,
    Permissoes.DATA_EDIT,
    Permissoes.DATA_DELETE,
    Permissoes.REPORTS_VIEW,
    Permissoes.ANALYTICS_VIEW,
    Permissoes.CONFIG_EDIT,
    Permissoes.EXPORT_DATA,
  ],
  'medico': [
    Permissoes.ORG_VIEW,
    Permissoes.IDOSO_VIEW,
    Permissoes.IDOSO_EDIT,
    Permissoes.DATA_VIEW,
    Permissoes.DATA_EDIT,
    Permissoes.DATA_DELETE,
    Permissoes.MEMBER_VIEW,
    Permissoes.REPORTS_VIEW,
    Permissoes.ANALYTICS_VIEW,
  ],
  'enfermeiro': [
    Permissoes.ORG_VIEW,
    Permissoes.IDOSO_VIEW,
    Permissoes.IDOSO_EDIT,
    Permissoes.IDOSO_ADD,
    Permissoes.DATA_VIEW,
    Permissoes.DATA_EDIT,
    Permissoes.MEMBER_VIEW,
    Permissoes.REPORTS_VIEW,
  ],
  'cuidador': [
    Permissoes.ORG_VIEW,
    Permissoes.IDOSO_VIEW,
    Permissoes.DATA_VIEW,
    Permissoes.DATA_EDIT,
  ],
  'recepcionista': [
    Permissoes.ORG_VIEW,
    Permissoes.IDOSO_VIEW,
    Permissoes.DATA_VIEW,
  ],
};

/// Service de permissões de organização
class PermissaoOrganizacaoService {
  /// Verifica se um role tem uma permissão específica
  static bool hasPermission(String? role, String permission) {
    if (role == null) return false;
    final permissions = ROLE_PERMISSIONS[role] ?? [];
    return permissions.contains(permission);
  }

  /// Verifica se pode gerenciar membros
  static bool podeGerenciarMembros(String? role) {
    return hasPermission(role, Permissoes.MEMBER_ADD) || 
           hasPermission(role, Permissoes.MEMBER_EDIT);
  }

  /// Verifica se pode gerenciar idosos
  static bool podeGerenciarIdosos(String? role) {
    return hasPermission(role, Permissoes.IDOSO_ADD) || 
           hasPermission(role, Permissoes.IDOSO_EDIT);
  }

  /// Verifica se pode confirmar eventos (medicamentos, rotinas)
  static bool podeConfirmarEventos(String? role) {
    return hasPermission(role, Permissoes.DATA_EDIT);
  }

  /// Verifica se pode gerenciar compromissos
  static bool podeGerenciarCompromissos(String? role) {
    return hasPermission(role, Permissoes.DATA_EDIT);
  }

  /// Verifica se pode ver relatórios
  static bool podeVerRelatorios(String? role) {
    return hasPermission(role, Permissoes.REPORTS_VIEW);
  }

  /// Verifica se pode gerenciar configurações
  static bool podeGerenciarConfiguracoes(String? role) {
    return hasPermission(role, Permissoes.CONFIG_EDIT);
  }

  /// Verifica se pode ver analytics
  static bool podeVerAnalytics(String? role) {
    return hasPermission(role, Permissoes.ANALYTICS_VIEW);
  }

  /// Verifica se pode exportar dados
  static bool podeExportarDados(String? role) {
    return hasPermission(role, Permissoes.EXPORT_DATA);
  }

  /// Verifica permissão genérica
  static bool verificarPermissao(String? role, String permissao) {
    return hasPermission(role, permissao);
  }

  /// Obtém lista de permissões do role
  static List<String> getPermissoesDoRole(String? role) {
    if (role == null) return [];
    return ROLE_PERMISSIONS[role] ?? [];
  }

  /// Verifica se pode deletar idoso (requer permissão específica)
  static bool podeDeletarIdoso(String? role) {
    return hasPermission(role, Permissoes.IDOSO_REMOVE);
  }

  /// Verifica se pode remover membro (requer permissão específica)
  static bool podeRemoverMembro(String? role) {
    return hasPermission(role, Permissoes.MEMBER_REMOVE);
  }

  /// Verifica se pode ver dados sensíveis
  static bool podeVerDadosSensiveis(String? role) {
    return hasPermission(role, Permissoes.DATA_VIEW);
  }

  /// Verifica se pode editar dados sensíveis
  static bool podeEditarDadosSensiveis(String? role) {
    return hasPermission(role, Permissoes.DATA_EDIT);
  }

  /// Verifica se pode deletar dados sensíveis
  static bool podeDeletarDadosSensiveis(String? role) {
    return hasPermission(role, Permissoes.DATA_DELETE);
  }
}

/// Hook para verificar permissão no contexto atual (Riverpod)
class PermissaoHook {
  final String? role;

  PermissaoHook(this.role);

  /// Verifica uma permissão específica
  bool has(String permission) {
    return PermissaoOrganizacaoService.hasPermission(role, permission);
  }

  /// Verifica se tem pelo menos uma das permissões
  bool hasAny(List<String> permissions) {
    return permissions.any((p) => has(p));
  }

  /// Verifica se tem todas as permissões
  bool hasAll(List<String> permissions) {
    return permissions.every((p) => has(p));
  }

  // Getters rápidos
  bool get isAdmin => role == 'admin';
  bool get isMedico => role == 'medico';
  bool get isEnfermeiro => role == 'enfermeiro';
  bool get isCuidador => role == 'cuidador';
  bool get isRecepcionista => role == 'recepcionista';

  bool get podeGerenciarMembros => PermissaoOrganizacaoService.podeGerenciarMembros(role);
  bool get podeGerenciarIdosos => PermissaoOrganizacaoService.podeGerenciarIdosos(role);
  bool get podeConfirmarEventos => PermissaoOrganizacaoService.podeConfirmarEventos(role);
  bool get podeVerRelatorios => PermissaoOrganizacaoService.podeVerRelatorios(role);
  bool get podeVerAnalytics => PermissaoOrganizacaoService.podeVerAnalytics(role);
  bool get podeGerenciarConfiguracoes => PermissaoOrganizacaoService.podeGerenciarConfiguracoes(role);
  bool get podeExportarDados => PermissaoOrganizacaoService.podeExportarDados(role);
  bool get podeDeletarIdoso => PermissaoOrganizacaoService.podeDeletarIdoso(role);
  bool get podeRemoverMembro => PermissaoOrganizacaoService.podeRemoverMembro(role);
}

/// Provider para hook de permissões
final permissaoHookProvider = Provider.family<PermissaoHook, String?>((ref, role) {
  return PermissaoHook(role);
});