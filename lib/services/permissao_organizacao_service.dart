/// Serviço para gerenciar permissões granulares de organização
/// PADRONIZADO com o Site (src/lib/utils/permissions.ts)
class PermissaoOrganizacaoService {
  /// Permissões disponíveis (padronizadas com Site)
  static const String orgView = 'org:view';
  static const String orgEdit = 'org:edit';
  static const String orgDelete = 'org:delete';
  static const String memberView = 'member:view';
  static const String memberAdd = 'member:add';
  static const String memberEdit = 'member:edit';
  static const String memberRemove = 'member:remove';
  static const String idosoView = 'idoso:view';
  static const String idosoAdd = 'idoso:add';
  static const String idosoEdit = 'idoso:edit';
  static const String idosoRemove = 'idoso:remove';
  static const String dataView = 'data:view';
  static const String dataEdit = 'data:edit';
  static const String dataDelete = 'data:delete';

  /// Permissões legadas (mantidas para compatibilidade)
  static const String gerenciarIdosos = 'gerenciar_idosos';
  static const String gerenciarMembros = 'gerenciar_membros';
  static const String verRelatorios = 'ver_relatorios';
  static const String gerenciarConfiguracoes = 'gerenciar_configuracoes';
  static const String verAnalytics = 'ver_analytics';
  static const String exportarDados = 'exportar_dados';
  static const String confirmarEventos = 'confirmar_eventos';
  static const String gerenciarCompromissos = 'gerenciar_compromissos';

  /// Mapeamento de roles para permissões (PADRONIZADO com Site)
  static final Map<String, List<String>> _permissoesPorRole = {
    'admin': [
      // Todas as permissões
      orgView, orgEdit, orgDelete,
      memberView, memberAdd, memberEdit, memberRemove,
      idosoView, idosoAdd, idosoEdit, idosoRemove,
      dataView, dataEdit, dataDelete,
      // Legadas
      gerenciarIdosos, gerenciarMembros, verRelatorios,
      gerenciarConfiguracoes, verAnalytics, exportarDados,
      confirmarEventos, gerenciarCompromissos,
    ],
    'medico': [
      orgView,
      idosoView, idosoEdit,
      dataView, dataEdit, dataDelete,
      memberView, // ✅ Pode ver membros (igual ao Site)
      // Legadas
      gerenciarIdosos, verRelatorios, verAnalytics,
      confirmarEventos, gerenciarCompromissos,
    ],
    'enfermeiro': [
      orgView,
      idosoView, idosoEdit, idosoAdd,
      dataView, dataEdit,
      memberView, // ✅ Pode ver membros (igual ao Site)
      // Legadas
      gerenciarIdosos, verRelatorios, verAnalytics,
      confirmarEventos, gerenciarCompromissos,
    ],
    'cuidador': [
      orgView,
      idosoView,
      dataView, dataEdit,
      // Legadas
      verRelatorios, confirmarEventos,
    ],
    'recepcionista': [
      orgView,
      idosoView,
      dataView,
      // Legadas
      verRelatorios, gerenciarCompromissos,
    ],
  };

  /// Verificar se um role tem uma permissão específica
  static bool verificarPermissao(String? role, String permissao) {
    if (role == null) return false;
    
    final permissoes = _permissoesPorRole[role] ?? [];
    return permissoes.contains(permissao);
  }

  /// Obter todas as permissões de um role
  static List<String> obterPermissoes(String? role) {
    if (role == null) return [];
    return _permissoesPorRole[role] ?? [];
  }

  /// Verificar se pode gerenciar idosos
  static bool podeGerenciarIdosos(String? role) {
    return verificarPermissao(role, gerenciarIdosos);
  }

  /// Verificar se pode gerenciar membros
  static bool podeGerenciarMembros(String? role) {
    return verificarPermissao(role, gerenciarMembros);
  }

  /// Verificar se pode ver relatórios
  static bool podeVerRelatorios(String? role) {
    return verificarPermissao(role, verRelatorios);
  }

  /// Verificar se pode gerenciar configurações
  static bool podeGerenciarConfiguracoes(String? role) {
    return verificarPermissao(role, gerenciarConfiguracoes);
  }

  /// Verificar se pode ver analytics
  static bool podeVerAnalytics(String? role) {
    return verificarPermissao(role, verAnalytics);
  }

  /// Verificar se pode exportar dados
  static bool podeExportarDados(String? role) {
    return verificarPermissao(role, exportarDados);
  }

  /// Verificar se pode confirmar eventos
  static bool podeConfirmarEventos(String? role) {
    return verificarPermissao(role, confirmarEventos);
  }

  /// Verificar se pode gerenciar compromissos
  static bool podeGerenciarCompromissos(String? role) {
    return verificarPermissao(role, gerenciarCompromissos);
  }
}

