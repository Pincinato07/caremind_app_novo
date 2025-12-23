import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/organizacao_service.dart';
import '../services/permissao_organizacao_service.dart';
import '../services/supabase_service.dart';
import '../core/injection/injection.dart';

/// State class para organização
class OrganizacaoState {
  final Organizacao? organizacaoAtual;
  final String? roleAtual;
  final List<Organizacao> organizacoes;
  final bool isLoading;
  final bool isModoOrganizacao;

  OrganizacaoState({
    this.organizacaoAtual,
    this.roleAtual,
    List<Organizacao>? organizacoes,
    this.isLoading = false,
    this.isModoOrganizacao = false,
  }) : organizacoes = organizacoes ?? [];

  bool get isAdmin => roleAtual == 'admin';
  bool get isMembroOrganizacao => organizacaoAtual != null;

  OrganizacaoState copyWith({
    Organizacao? organizacaoAtual,
    String? roleAtual,
    List<Organizacao>? organizacoes,
    bool? isLoading,
    bool? isModoOrganizacao,
  }) {
    return OrganizacaoState(
      organizacaoAtual: organizacaoAtual ?? this.organizacaoAtual,
      roleAtual: roleAtual ?? this.roleAtual,
      organizacoes: organizacoes ?? this.organizacoes,
      isLoading: isLoading ?? this.isLoading,
      isModoOrganizacao: isModoOrganizacao ?? this.isModoOrganizacao,
    );
  }
}

/// Notifier para gerenciar estado da organização
class OrganizacaoNotifier extends StateNotifier<OrganizacaoState> {
  final OrganizacaoService _organizacaoService = getIt<OrganizacaoService>();
  final SupabaseService _supabaseService = getIt<SupabaseService>();

  OrganizacaoNotifier() : super(OrganizacaoState()) {
    carregarOrganizacoes();
  }

  /// Atualiza o último contexto usado pelo usuário no banco
  Future<void> _atualizarLastContext(String context) async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return;

      await _supabaseService.client.from('user_preferences').upsert({
        'user_id': user.id,
        'last_context': context,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Erro ao atualizar last_context: $e');
      // Não bloquear a troca de contexto se houver erro
    }
  }

  /// Carregar organizações do usuário
  Future<void> carregarOrganizacoes() async {
    state = state.copyWith(isLoading: true);

    try {
      final organizacoes = await _organizacaoService.listarOrganizacoes();
      state = state.copyWith(
        organizacoes: organizacoes,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Erro ao carregar organizações: $e');
      state = state.copyWith(
        organizacoes: [],
        isLoading: false,
      );
    }
  }

  /// Selecionar organização
  Future<void> selecionarOrganizacao(String organizacaoId) async {
    state = state.copyWith(isLoading: true);

    try {
      final organizacao =
          await _organizacaoService.obterOrganizacao(organizacaoId);
      final role =
          await _organizacaoService.obterRoleOrganizacao(organizacaoId);

      state = state.copyWith(
        organizacaoAtual: organizacao,
        roleAtual: role,
        isModoOrganizacao: true,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Erro ao selecionar organização: $e');
      state = state.copyWith(
        organizacaoAtual: null,
        roleAtual: null,
        isModoOrganizacao: false,
        isLoading: false,
      );
    }
  }

  /// Alternar para modo pessoal
  Future<void> alternarModoPessoal() async {
    state = state.copyWith(
      organizacaoAtual: null,
      roleAtual: null,
      isModoOrganizacao: false,
    );
    // Atualizar last_context no banco
    await _atualizarLastContext('individual');
  }

  /// Alternar para modo organização
  Future<void> alternarModoOrganizacao(String organizacaoId) async {
    await selecionarOrganizacao(organizacaoId);
    // Atualizar last_context no banco após selecionar organização
    await _atualizarLastContext('organizacao');
  }

  /// Verificar permissões (métodos legados - mantidos para compatibilidade)
  bool podeGerenciarMembros() {
    return PermissaoOrganizacaoService.podeGerenciarMembros(state.roleAtual);
  }

  bool podeGerenciarIdosos() {
    return PermissaoOrganizacaoService.podeGerenciarIdosos(state.roleAtual);
  }

  bool podeConfirmarEventos() {
    return PermissaoOrganizacaoService.podeConfirmarEventos(state.roleAtual);
  }

  bool podeGerenciarCompromissos() {
    return PermissaoOrganizacaoService.podeGerenciarCompromissos(state.roleAtual);
  }

  /// Novos métodos de verificação de permissão
  bool podeVerRelatorios() {
    return PermissaoOrganizacaoService.podeVerRelatorios(state.roleAtual);
  }

  bool podeGerenciarConfiguracoes() {
    return PermissaoOrganizacaoService.podeGerenciarConfiguracoes(state.roleAtual);
  }

  bool podeVerAnalytics() {
    return PermissaoOrganizacaoService.podeVerAnalytics(state.roleAtual);
  }

  bool podeExportarDados() {
    return PermissaoOrganizacaoService.podeExportarDados(state.roleAtual);
  }

  /// Verificar permissão genérica
  bool verificarPermissao(String permissao) {
    return PermissaoOrganizacaoService.verificarPermissao(
        state.roleAtual, permissao);
  }

  /// Atualizar organização atual
  Future<void> atualizarOrganizacaoAtual() async {
    if (state.organizacaoAtual != null) {
      await selecionarOrganizacao(state.organizacaoAtual!.id);
    }
  }
}

/// Provider Riverpod
final organizacaoProvider =
    StateNotifierProvider<OrganizacaoNotifier, OrganizacaoState>(
  (ref) => OrganizacaoNotifier(),
);
