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

  Future<Perfil?> handleSignup(String email, String password, String nome, bool lgpdConsent, {String tipo = 'individual', String? telefone}) async {
    if (!lgpdConsent) {
      throw const ValidationException(message: 'Consentimento para compartilhamento de dados de saúde é obrigatório (LGPD)');
    }

    try {
      final response = await supabase.signUp(
        email: email,
        password: password,
        nome: nome,
        tipo: tipo,
        telefone: telefone,
        lgpdConsent: lgpdConsent,
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

  Future<Perfil?> handleGoogleSignIn() async {
    try {
      // Iniciar OAuth - abre o navegador
      await supabase.signInWithGoogle();
      
      // O OAuth abre o navegador, então precisamos aguardar o callback
      // O Supabase gerencia isso automaticamente via deep link
      // Após o callback, a sessão será estabelecida automaticamente
      
      // Aguardar o callback processar (polling)
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verificar se há usuário autenticado
        final user = supabase.currentUser;
        if (user != null) {
          // Sincronizar metadados do Google com perfil
          final userMetadata = user.userMetadata;
          if (userMetadata != null) {
            final fullName = userMetadata['full_name'] as String?;
            final avatarUrl = userMetadata['avatar_url'] as String?;
            
            if (fullName != null || avatarUrl != null) {
              final existingProfile = await supabase.getProfile(user.id);
              
              if (existingProfile != null) {
                // Atualizar perfil se necessário
                await supabase.updateProfile(
                  userId: user.id,
                  nome: fullName ?? existingProfile.nome,
                  fotoUsuario: avatarUrl ?? existingProfile.fotoUsuario,
                );
              } else if (fullName != null) {
                // Criar perfil básico se não existir
                await supabase.signUp(
                  email: user.email ?? '',
                  password: '', // Não necessário para OAuth
                  nome: fullName,
                  tipo: 'individual',
                  lgpdConsent: false, // Usuário precisará aceitar depois
                );
              }
            }
          }
          
          final perfil = await supabase.getProfile(user.id);
          return perfil;
        }
      }
      
      throw const AuthenticationException(message: 'Timeout ao aguardar autenticação Google');
    } catch (e) {
      throw ErrorHandler.toAppException(e);
    }
  }
}