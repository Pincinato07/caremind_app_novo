import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/convite_idoso_service.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';
import '../../widgets/wave_background.dart';
import '../../theme/app_theme.dart';
import '../shared/main_navigator_screen.dart';

/// Tela para processar convites de login para idosos
class ProcessarConviteScreen extends StatefulWidget {
  final String tokenOuCodigo;

  const ProcessarConviteScreen({
    super.key,
    required this.tokenOuCodigo,
  });

  @override
  State<ProcessarConviteScreen> createState() => _ProcessarConviteScreenState();
}

class _ProcessarConviteScreenState extends State<ProcessarConviteScreen> {
  bool _isProcessing = true;
  String? _error;
  String? _successMessage;
  ConviteResultado? _resultado;

  @override
  void initState() {
    super.initState();
    _processarConvite();
  }

  Future<void> _processarConvite() async {
    try {
      final supabase = Supabase.instance.client;
      final conviteService = getIt<ConviteIdosoService>();

      // Validar convite
      final resultado = await conviteService.processarConvite(widget.tokenOuCodigo);

      if (!mounted) return;

      if (!resultado.sucesso) {
        setState(() {
          _isProcessing = false;
          _error = resultado.erro ?? 'Erro ao processar convite.';
        });
        return;
      }

      // Buscar email do idoso para fazer login
      if (resultado.emailIdoso == null) {
        setState(() {
          _isProcessing = false;
          _error = 'Email do idoso não encontrado. Entre em contato com o familiar.';
        });
        return;
      }

      // Verificar se o usuário já está logado
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        // Se já está logado, verificar se é o idoso correto
        final perfil = await getIt<SupabaseService>().getProfile(currentUser.id);
        if (perfil?.id == resultado.idIdoso) {
          // Já é o idoso correto - buscar perfil e navegar
          final supabaseService = getIt<SupabaseService>();
          final perfil = await supabaseService.getProfile(currentUser.id);
          if (perfil != null) {
            await conviteService.marcarConviteComoUsado(
              widget.tokenOuCodigo,
              currentUser.id,
            );
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => MainNavigatorScreen(perfil: perfil),
                ),
                (route) => false,
              );
            }
          }
          return;
        } else {
          // É outro usuário - fazer logout primeiro
          await supabase.auth.signOut();
        }
      }

      // Buscar o perfil do idoso diretamente pela tabela perfis
      final perfilResponse = await supabase
          .from('perfis')
          .select('user_id, nome')
          .eq('id', resultado.idIdoso!)
          .maybeSingle();

      if (perfilResponse == null || perfilResponse['user_id'] == null) {
        setState(() {
          _isProcessing = false;
          _error = 'Perfil do idoso não encontrado.';
        });
        return;
      }

      final userId = perfilResponse['user_id'] as String;

      // Buscar email do usuário pelo user_id
      final authUserResponse = await supabase.auth.admin.getUserById(userId);
      final emailIdoso = authUserResponse.user?.email;

      if (emailIdoso == null) {
        setState(() {
          _isProcessing = false;
          _error = 'Email do idoso não encontrado. Entre em contato com o familiar.';
        });
        return;
      }

      // Mostrar mensagem informando que precisa da senha
      setState(() {
        _isProcessing = false;
        _error = 'Para fazer login, você precisa da senha criada pelo familiar. Entre em contato com ele para obter a senha.';
        _resultado = resultado;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Erro ao processar convite: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _fazerLoginComSenha(String senha) async {
    if (_resultado?.emailIdoso == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final supabaseService = getIt<SupabaseService>();
      final response = await supabaseService.signIn(
        email: _resultado!.emailIdoso!,
        password: senha,
      );

      if (!mounted) return;

      if (response.user != null) {
        // Buscar perfil e marcar convite como usado
        final supabaseService = getIt<SupabaseService>();
        final perfil = await supabaseService.getProfile(response.user!.id);
        if (perfil != null) {
          final conviteService = getIt<ConviteIdosoService>();
          await conviteService.marcarConviteComoUsado(
            widget.tokenOuCodigo,
            response.user!.id,
          );

          // Navegar para o dashboard
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => MainNavigatorScreen(perfil: perfil),
              ),
              (route) => false,
            );
          }
        } else {
          setState(() {
            _isProcessing = false;
            _error = 'Erro ao carregar perfil. Tente novamente.';
          });
        }
      } else {
        setState(() {
          _isProcessing = false;
          _error = 'Erro ao fazer login. Verifique a senha.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Erro ao fazer login: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const WaveBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                    if (_isProcessing) ...[
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Processando convite...',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aguarde enquanto validamos seu convite.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else if (_error != null) ...[
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Erro ao Processar Convite',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_resultado != null && _resultado!.emailIdoso != null) ...[
                        const SizedBox(height: 24),
                        _buildLoginForm(),
                      ] else ...[
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text('Voltar'),
                        ),
                      ],
                    ] else if (_successMessage != null) ...[
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Convite Válido!',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _successMessage!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    final _senhaController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Digite a senha para fazer login:',
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _senhaController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Senha',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Digite a senha';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _fazerLoginComSenha(_senhaController.text);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Fazer Login'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

