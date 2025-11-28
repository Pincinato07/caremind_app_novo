import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/perfil.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import '../../services/supabase_service.dart';
import '../../services/account_manager_service.dart';

class AuthService {
  final SupabaseService supabase;
  final AccountManagerService accountManager;

  const AuthService(this.supabase, this.accountManager);

  Future<Perfil?> handleLogin(String email, String password) async {
    try {
      final response = await supabase.signIn(email: email, password: password);
      if (response.user == null) {
        throw const AuthenticationException(message: 'Credenciais inválidas');
      }
      final perfil = await supabase.getProfile(response.user!.id);
      return perfil;
    } catch (e) {
      throw ErrorHandler.toAppException(e);
    }
  }

  Future<Perfil?> handleSignup(String email, String password, String nome, bool lgpdConsent) async {
    if (!lgpdConsent) {
      throw const ValidationException(message: 'Consentimento para compartilhamento de dados de saúde é obrigatório (LGPD)');
    }

    try {
      // Default tipo baseado no UI default ('pessoal')
      final response = await supabase.signUp(
        email: email,
        password: password,
        nome: nome,
        tipo: 'pessoal',
      );
      if (response.user == null) {
        throw const AuthenticationException(message: 'Falha ao criar usuário');
      }

      // Poll para perfil (melhor que delay fixo de 500ms)
      for (int i = 0; i < 10; i++) {
        final perfil = await supabase.getProfile(response.user!.id);
        if (perfil != null) {
          return perfil;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      throw UnknownException(
        message: 'Timeout ao carregar perfil após cadastro. Tente fazer login manualmente.',
      );
    } catch (e) {
      throw ErrorHandler.toAppException(e);
    }
  }
}