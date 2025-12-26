import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final bool? ultimoVerificacaoAtivo; // Status da última verificação de heartbeat

  OrganizacaoState({
    this.organizacaoAtual,
    this.roleAtual,
    List<Organizacao>? organizacoes,
    this.isLoading = false,
    this.isModoOrganizacao = false,
    this.ultimoVerificacaoAtivo,
  }) : organizacoes = organizacoes ?? [];

  bool get isAdmin => roleAtual == 'admin';
  bool get isMembroOrganizacao => organizacaoAtual != null;

  OrganizacaoState copyWith({
    Organizacao? organizacaoAtual,
    String? roleAtual,
    List<Organizacao>? organizacoes,
    bool? isLoading,
    bool? isModoOrganizacao,
    bool? ultimoVerificacaoAtivo,
  }) {
    return OrganizacaoState(
      organizacaoAtual: organizacaoAtual ?? this.organizacaoAtual,
      roleAtual: roleAtual ?? this.roleAtual,
      organizacoes: organizacoes ?? this.organizacoes,
      isLoading: isLoading ?? this.isLoading,
      isModoOrganizacao: isModoOrganizacao ?? this.isModoOrganizacao,
      ultimoVerificacaoAtivo: ultimoVerificacaoAtivo ?? this.ultimoVerificacaoAtivo,
    );
  }
}

/// Notifier para gerenciar estado da organização
class OrganizacaoNotifier extends StateNotifier<OrganizacaoState> {
  final OrganizacaoService _organizacaoService = getIt<OrganizacaoService>();
  final SupabaseService _supabaseService = getIt<SupabaseService>();
  
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeatTime;

  OrganizacaoNotifier() : super(OrganizacaoState()) {
    carregarOrganizacoes();
    _iniciarHeartbeat();
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

  /// Heartbeat: Verifica se o usuário ainda é membro ativo da organização
  Future<bool> _verificarMembroAtivo() async {
    if (state.organizacaoAtual == null) {
      return false;
    }

    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) {
        return false;
      }

      // Obter perfil do usuário
      final perfil = await _supabaseService.client
          .from('perfis')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (perfil == null) {
        return false;
      }

      // Verificar se ainda é membro ativo
      final membro = await _supabaseService.client
          .from('membros_organizacao')
          .select('id')
          .eq('organizacao_id', state.organizacaoAtual!.id)
          .eq('perfil_id', perfil['id'])
          .eq('ativo', true)
          .maybeSingle();

      final isAtivo = membro != null;
      
      if (!isAtivo) {
        debugPrint('⚠️ HEARTBEAT: Usuário removido da organização!');
        
        // Alternar para modo pessoal
        await alternarModoPessoal();
        
        // Mostrar alerta
        _mostrarAlertaRevogado();
      }

      state = state.copyWith(ultimoVerificacaoAtivo: isAtivo);
      return isAtivo;
    } catch (e) {
      debugPrint('Erro no heartbeat: $e');
      return false;
    }
  }

  /// Inicia o heartbeat (verificação periódica)
  void _iniciarHeartbeat() {
    // Limpar timer existente
    _heartbeatTimer?.cancel();
    
    // Verificar a cada 30 minutos (1.800.000 ms)
    _heartbeatTimer = Timer.periodic(Duration(minutes: 30), (timer) async {
      if (state.organizacaoAtual != null) {
        debugPrint('❤️ Heartbeat: Verificando permissão...');
        await _verificarMembroAtivo();
      }
    });

    // Listener para quando app voltar do background
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(
      onResumed: () async {
        if (state.organizacaoAtual != null) {
          final now = DateTime.now();
          if (_lastHeartbeatTime == null || 
              now.difference(_lastHeartbeatTime!).inMinutes > 1) {
            debugPrint('❤️ Heartbeat (background): Verificando permissão...');
            _lastHeartbeatTime = now;
            await _verificarMembroAtivo();
          }
        }
      }
    ));
  }

  /// Mostra alerta de acesso revogado
  void _mostrarAlertaRevogado() {
    // Usar um callback ou stream para notificar a UI
    // Por enquanto, apenas log
    debugPrint('🚨 ALERTA: Seu acesso a esta organização foi revogado!');
    
    // Disparar evento que a UI pode ouvir
    // (Implementar conforme necessidade do app)
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

      // Verificar imediatamente após selecionar
      await _verificarMembroAtivo();
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
      ultimoVerificacaoAtivo: null,
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

  /// Verificar membro ativo manualmente (para uso externo)
  Future<bool> verificarMembroAtivo() async {
    return await _verificarMembroAtivo();
  }

  /// Dispose
  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

/// Observer para lifecycle (background/foreground)
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResumed;

  _AppLifecycleObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

/// Provider Riverpod
final organizacaoProvider =
    StateNotifierProvider<OrganizacaoNotifier, OrganizacaoState>(
  (ref) => OrganizacaoNotifier(),
);
