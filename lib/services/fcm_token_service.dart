import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// Serviço para gerenciar tokens FCM e sincronizar com o backend Supabase
/// 
/// Responsável por:
/// - Obter e armazenar tokens FCM do dispositivo
/// - Sincronizar tokens com o Supabase (tabela `fcm_tokens`)
/// - Atualizar tokens quando mudarem
/// - Remover tokens quando o usuário fizer logout
class FCMTokenService {
  final SupabaseClient _client;
  String? _currentToken;

  FCMTokenService(this._client);

  /// Inicializar o serviço e registrar listener para mudanças de token
  Future<void> initialize() async {
    try {
      // Obter token FCM atual
      final token = await NotificationService.getFCMToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('✅ FCMTokenService: Token obtido: $token');
      }

      // Registrar callback para quando o token for atualizado
      NotificationService.onFcmTokenUpdated = (newToken) async {
        if (_currentToken != newToken) {
          _currentToken = newToken;
          debugPrint('🔄 FCMTokenService: Token atualizado, sincronizando...');
          await syncTokenToBackend();
        }
      };

      // Sincronizar token atual com backend se usuário estiver logado
      final user = _client.auth.currentUser;
      if (user != null && token != null) {
        await syncTokenToBackend();
      }

      // Listener para mudanças de autenticação
      _client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn) {
          syncTokenToBackend();
        } else if (event == AuthChangeEvent.signedOut) {
          removeTokenFromBackend();
        }
      });
    } catch (e) {
      debugPrint('❌ FCMTokenService: Erro ao inicializar - ${e.toString()}');
    }
  }

  /// Sincronizar token FCM atual com o backend Supabase
  /// 
  /// Salva ou atualiza o token na tabela `fcm_tokens` associado ao usuário atual.
  /// A tabela deve ter a seguinte estrutura:
  /// ```sql
  /// CREATE TABLE fcm_tokens (
  ///   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ///   user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ///   token TEXT NOT NULL UNIQUE,
  ///   platform TEXT NOT NULL, -- 'android' ou 'ios'
  ///   created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ///   updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ///   UNIQUE(user_id, token)
  /// );
  /// ```
  Future<void> syncTokenToBackend() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ FCMTokenService: Usuário não autenticado, não é possível sincronizar token');
        return;
      }

      final token = _currentToken ?? await NotificationService.getFCMToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ FCMTokenService: Token FCM não disponível');
        return;
      }


      // Determinar plataforma
      final platform = defaultTargetPlatform == TargetPlatform.android
          ? 'android'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'unknown';

      // Verificar se já existe um token para este usuário
      final existingToken = await _client
          .from('fcm_tokens')
          .select()
          .eq('perfil_id', user.id)
          .eq('token', token)
          .maybeSingle();

      if (existingToken != null) {
        // Token já existe, apenas atualizar updated_at
        await _client
            .from('fcm_tokens')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existingToken['id']);
        debugPrint('✅ FCMTokenService: Token atualizado no backend');
      } else {
        // Remover tokens antigos do mesmo usuário (um usuário pode ter múltiplos dispositivos)
        // Mas manter o token atual se for diferente
        await _client
            .from('fcm_tokens')
            .delete()
            .eq('perfil_id', user.id)
            .neq('token', token);

        // Inserir novo token
        await _client.from('fcm_tokens').insert({
          'perfil_id': user.id,
          'token': token,
          'platform': platform,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ FCMTokenService: Token salvo no backend');
      }
    } catch (e) {
      debugPrint('❌ FCMTokenService: Erro ao sincronizar token - ${e.toString()}');
      // Não lançar exceção para não quebrar o fluxo do app
    }
  }

  /// Remover token FCM do backend quando o usuário fizer logout
  Future<void> removeTokenFromBackend() async {
    try {
      if (_currentToken == null) return;

      await _client
          .from('fcm_tokens')
          .delete()
          .eq('token', _currentToken!);

      _currentToken = null;
      debugPrint('✅ FCMTokenService: Token removido do backend');
    } catch (e) {
      debugPrint('❌ FCMTokenService: Erro ao remover token - ${e.toString()}');
    }
  }

  /// Obter token FCM atual
  String? get currentToken => _currentToken;

  /// Forçar sincronização do token (útil após login)
  Future<void> forceSync() async {
    final token = await NotificationService.getFCMToken();
    _currentToken = token;
    await syncTokenToBackend();
  }
}

