import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notificacao_app.dart';
import '../core/errors/error_handler.dart';

/// Service para gerenciar notificações do app (tabela notificacoes_app)
/// 
/// Responsável por:
/// - Buscar notificações do usuário
/// - Marcar como lida
/// - Contar não lidas
/// - Escutar novas notificações em tempo real
class NotificacoesAppService {
  final SupabaseClient _client;
  
  // Stream controller para notificações em tempo real
  final StreamController<List<NotificacaoApp>> _notificacoesController = 
      StreamController<List<NotificacaoApp>>.broadcast();
  
  // Stream controller para contagem de não lidas
  final StreamController<int> _countController = 
      StreamController<int>.broadcast();
  
  // Subscription do realtime
  RealtimeChannel? _realtimeChannel;
  
  // Cache local
  List<NotificacaoApp> _cache = [];
  int _countNaoLidas = 0;

  NotificacoesAppService(this._client);

  /// Stream de notificações (para usar com StreamBuilder)
  Stream<List<NotificacaoApp>> get notificacoesStream => _notificacoesController.stream;
  
  /// Stream de contagem de não lidas
  Stream<int> get countNaoLidasStream => _countController.stream;
  
  /// Contagem atual de não lidas
  int get countNaoLidas => _countNaoLidas;
  
  /// Lista de notificações em cache
  List<NotificacaoApp> get notificacoes => _cache;

  /// Inicializar o serviço e configurar realtime
  Future<void> initialize() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Carregar notificações iniciais
    await carregarNotificacoes();
    await atualizarContagem();

    // Configurar listener de realtime
    _setupRealtimeListener(user.id);
  }

  /// Configurar listener de realtime para novas notificações
  void _setupRealtimeListener(String perfilId) {
    _realtimeChannel?.unsubscribe();
    
    _realtimeChannel = _client
        .channel('notificacoes_app_$perfilId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notificacoes_app',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'perfil_id',
            value: perfilId,
          ),
          callback: (payload) {
            debugPrint('📬 Nova notificação recebida via realtime');
            _handleNovaNotificacao(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notificacoes_app',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'perfil_id',
            value: perfilId,
          ),
          callback: (payload) {
            _handleNotificacaoAtualizada(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Handler para nova notificação via realtime
  void _handleNovaNotificacao(Map<String, dynamic> data) {
    try {
      final notificacao = NotificacaoApp.fromMap(data);
      
      // Adicionar no início da lista
      _cache.insert(0, notificacao);
      _notificacoesController.add(_cache);
      
      // Atualizar contagem
      if (!notificacao.lida) {
        _countNaoLidas++;
        _countController.add(_countNaoLidas);
      }
    } catch (e) {
      debugPrint('❌ Erro ao processar nova notificação: $e');
    }
  }

  /// Handler para notificação atualizada via realtime
  void _handleNotificacaoAtualizada(Map<String, dynamic> data) {
    try {
      final notificacao = NotificacaoApp.fromMap(data);
      
      // Atualizar no cache
      final index = _cache.indexWhere((n) => n.id == notificacao.id);
      if (index != -1) {
        final antiga = _cache[index];
        _cache[index] = notificacao;
        _notificacoesController.add(_cache);
        
        // Atualizar contagem se mudou status de lida
        if (!antiga.lida && notificacao.lida) {
          _countNaoLidas = (_countNaoLidas - 1).clamp(0, 9999);
          _countController.add(_countNaoLidas);
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao processar atualização: $e');
    }
  }

  /// Carregar notificações do servidor
  Future<List<NotificacaoApp>> carregarNotificacoes({
    int limit = 50,
    int offset = 0,
    bool apenasNaoLidas = false,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      // Usar a função RPC para buscar notificações
      final response = await _client.rpc(
        'buscar_notificacoes',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_apenas_nao_lidas': apenasNaoLidas,
        },
      );

      final notificacoes = (response as List)
          .map((item) => NotificacaoApp.fromMap(item as Map<String, dynamic>))
          .toList();

      // Atualizar cache se é a primeira página
      if (offset == 0) {
        _cache = notificacoes;
        _notificacoesController.add(_cache);
      } else {
        // Adicionar à lista existente (paginação)
        _cache.addAll(notificacoes);
        _notificacoesController.add(_cache);
      }

      return notificacoes;
    } catch (e) {
      debugPrint('❌ Erro ao carregar notificações: $e');
      throw ErrorHandler.toAppException(e);
    }
  }

  /// Atualizar contagem de não lidas
  Future<int> atualizarContagem() async {
    try {
      final response = await _client.rpc('contar_notificacoes_nao_lidas');
      _countNaoLidas = (response as int?) ?? 0;
      _countController.add(_countNaoLidas);
      return _countNaoLidas;
    } catch (e) {
      debugPrint('❌ Erro ao contar não lidas: $e');
      return _countNaoLidas;
    }
  }

  /// Marcar uma notificação como lida
  Future<bool> marcarComoLida(String notificacaoId) async {
    try {
      final response = await _client.rpc(
        'marcar_notificacao_lida',
        params: {'p_notificacao_id': notificacaoId},
      );

      if (response == true) {
        // Atualizar cache local
        final index = _cache.indexWhere((n) => n.id == notificacaoId);
        if (index != -1 && !_cache[index].lida) {
          _cache[index] = _cache[index].copyWith(
            lida: true,
            dataLeitura: DateTime.now(),
          );
          _notificacoesController.add(_cache);
          
          _countNaoLidas = (_countNaoLidas - 1).clamp(0, 9999);
          _countController.add(_countNaoLidas);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erro ao marcar como lida: $e');
      throw ErrorHandler.toAppException(e);
    }
  }

  /// Marcar todas as notificações como lidas
  Future<int> marcarTodasComoLidas() async {
    try {
      final response = await _client.rpc('marcar_todas_notificacoes_lidas');
      final count = (response as int?) ?? 0;

      // Atualizar cache local
      _cache = _cache.map((n) => n.copyWith(
        lida: true,
        dataLeitura: DateTime.now(),
      )).toList();
      _notificacoesController.add(_cache);
      
      _countNaoLidas = 0;
      _countController.add(_countNaoLidas);

      return count;
    } catch (e) {
      debugPrint('❌ Erro ao marcar todas como lidas: $e');
      throw ErrorHandler.toAppException(e);
    }
  }

  /// Limpar cache e fechar streams
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _notificacoesController.close();
    _countController.close();
    _cache.clear();
  }

  /// Reinicializar o serviço (útil após login/logout)
  Future<void> reinitialize() async {
    _cache.clear();
    _countNaoLidas = 0;
    await initialize();
  }
}

