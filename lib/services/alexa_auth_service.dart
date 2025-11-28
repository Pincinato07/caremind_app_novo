import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Serviço para autenticação e vinculação com Amazon Alexa
/// Usa fluxo OAuth seguro via Edge Function (sem client_secret no app)
class AlexaAuthService {
  final SupabaseService _supabaseService;
  
  // URL base da Edge Function
  String get _edgeFunctionBaseUrl => 
    '${dotenv.env['SUPABASE_URL']}/functions/v1';

  AlexaAuthService(this._supabaseService);

  /// Inicia o fluxo de vinculação com a Alexa
  /// Abre o navegador para autorização na Amazon
  Future<bool> startLinking() async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // URL da Edge Function que inicia o OAuth
      // A Edge Function redireciona para a Amazon com os parâmetros corretos
      final authUrl = Uri.parse(
        '$_edgeFunctionBaseUrl/alexa-auth-start?perfil_id=${user.id}',
      );

      debugPrint('🔗 Iniciando vinculação Alexa: $authUrl');

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(
          authUrl,
          mode: LaunchMode.externalApplication,
        );
        return true;
      } else {
        throw Exception('Não foi possível abrir o navegador');
      }
    } catch (e) {
      debugPrint('❌ Erro ao iniciar vinculação Alexa: $e');
      rethrow;
    }
  }

  /// Verifica se o usuário já tem a Alexa vinculada
  Future<bool> isLinked() async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) return false;

      final response = await Supabase.instance.client
          .from('user_integrations')
          .select('id')
          .eq('perfil_id', user.id)
          .eq('provider', 'amazon_alexa')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Erro ao verificar vinculação Alexa: $e');
      return false;
    }
  }

  /// Remove a vinculação com a Alexa
  Future<bool> unlink() async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      await Supabase.instance.client
          .from('user_integrations')
          .delete()
          .eq('perfil_id', user.id)
          .eq('provider', 'amazon_alexa');

      debugPrint('✅ Alexa desvinculada com sucesso');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao desvincular Alexa: $e');
      rethrow;
    }
  }

  /// Processa o callback do Deep Link após autorização
  /// Chamado quando o app recebe caremind://alexa-callback
  Future<void> handleCallback(Uri uri) async {
    debugPrint('📥 Callback Alexa recebido: $uri');
    
    final status = uri.queryParameters['status'];
    final error = uri.queryParameters['error'];
    
    if (status == 'success') {
      debugPrint('✅ Vinculação Alexa concluída com sucesso');
    } else if (error != null) {
      debugPrint('❌ Erro na vinculação Alexa: $error');
      throw Exception(error);
    }
  }
}

