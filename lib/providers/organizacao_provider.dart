import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/organizacao_service.dart';
import '../services/membro_organizacao_service.dart';
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

  OrganizacaoNotifier() : super(OrganizacaoState()) {
    carregarOrganizacoes();
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
      final organizacao = await _organizacaoService.obterOrganizacao(organizacaoId);
      final role = await _organizacaoService.obterRoleOrganizacao(organizacaoId);
      
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
  void alternarModoPessoal() {
    state = state.copyWith(
      organizacaoAtual: null,
      roleAtual: null,
      isModoOrganizacao: false,
    );
  }

  /// Alternar para modo organização
  Future<void> alternarModoOrganizacao(String organizacaoId) async {
    await selecionarOrganizacao(organizacaoId);
  }

  /// Verificar permissões
  bool podeGerenciarMembros() {
    return state.isAdmin;
  }

  bool podeGerenciarIdosos() {
    return ['admin', 'medico', 'enfermeiro'].contains(state.roleAtual);
  }

  bool podeConfirmarEventos() {
    return ['admin', 'medico', 'enfermeiro', 'cuidador'].contains(state.roleAtual);
  }

  bool podeGerenciarCompromissos() {
    return ['admin', 'medico', 'enfermeiro', 'recepcionista'].contains(state.roleAtual);
  }

  /// Atualizar organização atual
  Future<void> atualizarOrganizacaoAtual() async {
    if (state.organizacaoAtual != null) {
      await selecionarOrganizacao(state.organizacaoAtual!.id);
    }
  }
}

/// Provider Riverpod
final organizacaoProvider = StateNotifierProvider<OrganizacaoNotifier, OrganizacaoState>(
  (ref) => OrganizacaoNotifier(),
);
