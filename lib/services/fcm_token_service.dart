import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class FCMTokenService {
  final SupabaseClient _client;
  String? _currentToken;
  
  // Callback para notificar erros ao usuário
  Function(String message)? onSyncError;

  FCMTokenService(this._client);

  Future<void> initialize() async {
    try {
      final token = await NotificationService.getFCMToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('✅ FCMTokenService: Token obtido: $token');
      }

      NotificationService.onFcmTokenUpdated = (newToken) async {
        if (_currentToken != newToken) {
          _currentToken = newToken;
          debugPrint('🔄 FCMTokenService: Token atualizado, sincronizando...');
          await syncTokenToBackend();
        }
      };

      final user = _client.auth.currentUser;
      if (user != null && token != null) {
        await syncTokenToBackend();
      }

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
      onSyncError?.call(
        'Erro ao configurar notificações push. Você pode não receber alertas de medicamento.',
      );
    }
  }

  Future<String?> _getPerfilId(String userId) async {
    try {
      final response = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      return response?['id'] as String?;
    } catch (e) {
      debugPrint('⚠️ FCMTokenService: Erro ao buscar perfil_id: $e');
      return null;
    }
  }

  Future<void> syncTokenToBackend() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ FCMTokenService: Usuário não autenticado');
        return;
      }

      final token = _currentToken ?? await NotificationService.getFCMToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ FCMTokenService: Token FCM não disponível');
        return;
      }

      final perfilId = await _getPerfilId(user.id);
      if (perfilId == null) {
        debugPrint('⚠️ FCMTokenService: perfil_id não encontrado para user ${user.id}');
        return;
      }

      final platform = defaultTargetPlatform == TargetPlatform.android
          ? 'android'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'unknown';

      final existingToken = await _client
          .from('fcm_tokens')
          .select()
          .eq('perfil_id', perfilId)
          .eq('token', token)
          .maybeSingle();

      if (existingToken != null) {
        await _client
            .from('fcm_tokens')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existingToken['id']);
        debugPrint('✅ FCMTokenService: Token atualizado no backend');
      } else {
        await _client
            .from('fcm_tokens')
            .delete()
            .eq('perfil_id', perfilId)
            .neq('token', token);

        await _client.from('fcm_tokens').insert({
          'perfil_id': perfilId,
          'token': token,
          'platform': platform,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ FCMTokenService: Token salvo no backend');
      }
    } catch (e) {
      debugPrint('❌ FCMTokenService: Erro ao sincronizar token - ${e.toString()}');
      onSyncError?.call(
        'Erro ao sincronizar notificações com o servidor. Você pode não receber alertas de medicamento. Verifique sua conexão.',
      );
    }
  }

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

  String? get currentToken => _currentToken;

  Future<void> forceSync() async {
    final token = await NotificationService.getFCMToken();
    _currentToken = token;
    await syncTokenToBackend();
  }
}