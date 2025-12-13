import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_service.dart';
import '../../widgets/wave_background.dart';
import '../shared/main_navigator_screen.dart';
import '../../core/injection/injection.dart';

enum AuthMode { login, register }

class AuthShell extends StatefulWidget {
  final AuthMode initialMode;

  const AuthShell({super.key, this.initialMode = AuthMode.login});

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AuthMode _mode;
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _isLoginLoading = false;

  // Register
  int _registerStep = 0;
  final _registerFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedAccountType = 'pessoal';
  bool _termsAccepted = false;
  bool _dataSharingAccepted = false;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível abrir o link: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocorreu um erro ao tentar abrir o link')),
        );
      }
    }
  }

  // ==================== AUTH HANDLERS ====================

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoginLoading = true;
      });

      try {
        final email = _loginEmailController.text.trim();
        final password = _loginPasswordController.text;

        final supabaseService = getIt<SupabaseService>();
        final response = await supabaseService.signIn(
          email: email,
          password: password,
        );

        if (!mounted) return;

        if (response.user != null) {
          // Get user profile
          final perfil = await supabaseService.getProfile(response.user!.id);
          
          if (perfil != null && mounted) {
            // Navigate to main screen with profile
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => MainNavigatorScreen(perfil: perfil)),
              (_) => false,
            );
          } else {
            _showSnack('Erro ao carregar perfil. Tente novamente.');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('E-mail ou senha inválidos'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoginLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
                minWidth: 300,
              ),
              child: SingleChildScrollView(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
                      ),
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width > 600 ? 32 : 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Recuperar Senha',
                              style: GoogleFonts.leagueSpartan(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Digite seu e-mail para receber instruções de recuperação',
                              style: GoogleFonts.leagueSpartan(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            _glowField(
                              controller: emailController,
                              hint: 'seu@email.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v?.trim().isEmpty == true) return 'E-mail é obrigatório';
                                if (!v!.contains('@')) return 'E-mail inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _outlineButton(
                                    label: 'Cancelar',
                                    onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _primaryButton(
                                    label: 'Enviar',
                                    isLoading: isLoading,
                                    onPressed: isLoading
                                        ? null
                                        : () async {
                                            if (formKey.currentState?.validate() ?? false) {
                                              setDialogState(() => isLoading = true);
                                              try {
                                                final supabaseService = getIt<SupabaseService>();
                                                await supabaseService.resetPassword(emailController.text.trim());
                                                if (context.mounted) {
                                                  Navigator.of(context).pop(true);
                                                }
                                              } catch (e) {
                                                setDialogState(() => isLoading = false);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Erro ao enviar e-mail: $e'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    emailController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'E-mail de recuperação enviado! Verifique sua caixa de entrada.',
            style: GoogleFonts.leagueSpartan(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleSignUp() async {
    if (_isRegistering) return;
    setState(() => _isRegistering = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final confirm = _confirmPasswordController.text;

      if (name.isEmpty || !email.contains('@')) {
        _showSnack('Preencha corretamente nome e e-mail.');
        setState(() => _registerStep = 0);
        return;
      }
      if (password.length < 6 || password != confirm) {
        _showSnack('Verifique as senhas.');
        setState(() => _registerStep = 1);
        return;
      }
      if (!_termsAccepted) {
        _showSnack('Aceite os termos para continuar.');
        setState(() => _registerStep = 2);
        return;
      }

      final supabaseService = getIt<SupabaseService>();
      final response = await supabaseService.signUp(
        email: email,
        password: password,
        nome: name,
        tipo: _selectedAccountType,
      );

      if (!mounted) return;

      if (response.user != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        final perfil = await supabaseService.getProfile(response.user!.id);
        if (perfil != null && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MainNavigatorScreen(perfil: perfil)),
            (_) => false,
          );
        } else {
          _showSnack('Erro ao carregar perfil. Tente login.');
          setState(() => _mode = AuthMode.login);
        }
      }
    } catch (e) {
      _showSnack('Erro ao cadastrar: $e');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  // ==================== UTILS ====================

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _nextPage() {
    // Validate current step before advancing
    if (_registerStep == 0) {
      // Step 1: Validate name and email form
      if (!_registerFormKey.currentState!.validate()) {
        return;
      }
    } else if (_registerStep == 1) {
      // Step 2: Validate passwords form
      if (!_passwordFormKey.currentState!.validate()) {
        return;
      }
    }
    
    // If validation passes, advance to next step
    if (_registerStep < 2) {
      setState(() => _registerStep++);
    }
  }

  void _previousPage() {
    if (_registerStep > 0) {
      setState(() => _registerStep--);
    }
  }

  // ==================== GLASSMORPHISM ====================

  Widget _glassContainer({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BUTTONS ====================

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final baseColor = const Color(0xFF0400BA);
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return const Color(0xFF020054);
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
              return const Color(0xFF0600E0);
            }
            return baseColor;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(Colors.white.withAlpha(6)),
          elevation: WidgetStateProperty.all(6),
          shadowColor: WidgetStateProperty.all(baseColor.withAlpha(20)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.leagueSpartan(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(label),
      ),
    );
  }

  Widget _outlineButton({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: onPressed == null ? Colors.grey[400]! : Colors.white,
            width: 1.5,
          ),
          backgroundColor: Colors.white.withAlpha(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.leagueSpartan(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.leagueSpartan(
            color: onPressed == null ? Colors.grey[400] : Colors.white,
          ),
        ),
      ),
    );
  }

  // ==================== FIELDS ====================

  Widget _glowField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.leagueSpartan(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.leagueSpartan(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 15,
          ),
          filled: true,
          fillColor: Colors.white.withAlpha(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          errorStyle: GoogleFonts.leagueSpartan(
            color: Colors.redAccent,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ==================== ACCOUNT OPTION ====================

  Widget _buildAccountTypeOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedAccountType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccountType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withAlpha(30) : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withAlpha(50),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.leagueSpartan(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.leagueSpartan(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== REGISTER STEPS ====================

  Widget _buildStep1() {
    return Form(
      key: _registerFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _glowField(
            controller: _nameController,
            hint: 'Seu nome completo',
            validator: (v) {
              if (v?.trim().isEmpty == true) return 'Nome é obrigatório';
              return null;
            },
          ),
          _glowField(
            controller: _emailController,
            hint: 'seu@email.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v?.trim().isEmpty == true) return 'E-mail é obrigatório';
              if (!v!.contains('@')) return 'E-mail inválido';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _primaryButton(label: 'Continuar', onPressed: _nextPage),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _glowField(
            controller: _passwordController,
            hint: 'Crie uma senha',
            obscure: true,
            validator: (v) {
              if (v?.isEmpty == true) return 'Senha é obrigatória';
              if (v!.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          _glowField(
            controller: _confirmPasswordController,
            hint: 'Confirme a senha',
            obscure: true,
            validator: (v) {
              if (v?.isEmpty == true) return 'Confirme a senha';
              if (v != _passwordController.text) return 'Senhas não coincidem';
              return null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _outlineButton(label: 'Voltar', onPressed: _previousPage)),
              const SizedBox(width: 12),
              Expanded(child: _primaryButton(label: 'Continuar', onPressed: _nextPage)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tipo de conta',
          style: GoogleFonts.leagueSpartan(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAccountTypeOption(
                value: 'pessoal',
                icon: Icons.person,
                title: 'Pessoal',
                subtitle: 'Uso individual',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAccountTypeOption(
                value: 'profissional',
                icon: Icons.work,
                title: 'Profissional',
                subtitle: 'Para psicólogos',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              activeColor: Colors.white,
              checkColor: const Color(0xFF0400BA),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.leagueSpartan(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    children: [
                      const TextSpan(text: 'Li e aceito os '),
                      TextSpan(
                        text: 'Termos de Uso',
                        style: const TextStyle(decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _launchURL('https://caremind.com.br/termos'),
                      ),
                      const TextSpan(text: ' e '),
                      TextSpan(
                        text: 'Política de Privacidade',
                        style: const TextStyle(decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _launchURL('https://caremind.com.br/politica-privacidade'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _outlineButton(label: 'Voltar', onPressed: _previousPage)),
            const SizedBox(width: 12),
            Expanded(
              child: _primaryButton(
                label: 'Cadastrar',
                onPressed: _termsAccepted ? _handleSignUp : null,
                isLoading: _isRegistering,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== BUILD METHODS ====================

  Widget _buildLoginCard() {
    return _glassContainer(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Entrar na sua conta',
              style: GoogleFonts.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _glowField(
              controller: _loginEmailController,
              hint: 'E-mail',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'E-mail obrigatório';
                if (!v!.contains('@')) return 'E-mail inválido';
                return null;
              },
            ),
            _glowField(
              controller: _loginPasswordController,
              hint: 'Senha',
              obscure: true,
              validator: (v) => (v?.length ?? 0) < 6 ? 'Mínimo 6 caracteres' : null,
            ),
            const SizedBox(height: 24),
            _primaryButton(
              label: 'Entrar',
              onPressed: _isLoginLoading ? null : _handleLogin,
              isLoading: _isLoginLoading,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: Text(
                  'Esqueci minha senha',
                  style: GoogleFonts.leagueSpartan(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _mode = AuthMode.register;
                    _registerStep = 0;
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.leagueSpartan(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    children: const [
                      TextSpan(text: 'Não tem conta? '),
                      TextSpan(
                        text: 'Cadastre-se',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterCard() {
    return _glassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Criar Conta',
            style: GoogleFonts.leagueSpartan(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Passo ${_registerStep + 1} de 3',
            style: GoogleFonts.leagueSpartan(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          if (_registerStep == 0) _buildStep1(),
          if (_registerStep == 1) _buildStep2(),
          if (_registerStep == 2) _buildStep3(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: _registerStep == index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _registerStep == index ? Colors.white : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _mode = AuthMode.login),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.leagueSpartan(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  children: const [
                    TextSpan(text: 'Já tem conta? '),
                    TextSpan(
                      text: 'Faça login',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFA8B8FF), Color(0xFF9B7EFF)],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: WaveBackground(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - viewPadding.top - viewPadding.bottom),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/caremind_deitado.png',
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _mode == AuthMode.login
                            ? _buildLoginCard()
                            : _buildRegisterCard(),
                        key: ValueKey(_mode),
                      ),
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
}
