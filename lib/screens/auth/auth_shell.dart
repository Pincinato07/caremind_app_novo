import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_service.dart';
import '../../services/account_manager_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../widgets/wave_background.dart'; // Caminho correto
import '../shared/main_navigator_screen.dart';

enum AuthMode { login, register }

class AuthShell extends StatefulWidget {
  const AuthShell({super.key, this.initialMode = AuthMode.login});
  final AuthMode initialMode;

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
  final _registerPageController = PageController();
  int _registerStep = 0;

  // Step 1
  final _registerFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // Step 2
  final _passwordFormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 3
  String _selectedAccountType = 'pessoal';
  bool _termsAccepted = false;
  bool _consentimentoDadosSaude = false; // Consentimento explícito LGPD
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
    _registerPageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Não foi possível abrir o link: $url');
    }
  }

  // ==================== AUTH HANDLERS ====================

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoginLoading = true);
    try {
      final supabaseService = getIt<SupabaseService>();
      final response = await supabaseService.signIn(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (!mounted) return;

      if (response.user != null) {
        final perfil = await supabaseService.getProfile(response.user!.id);
        if (perfil != null && mounted) {
          // Salvar informações da conta para troca rápida
          final accountManager = AccountManagerService();
          String? fotoUrl;
          if (perfil.fotoUsuario != null && perfil.fotoUsuario!.isNotEmpty) {
            try {
              if (perfil.fotoUsuario!.startsWith('http')) {
                fotoUrl = perfil.fotoUsuario;
              } else {
                fotoUrl = supabaseService.client.storage
                    .from('avatars')
                    .getPublicUrl(perfil.fotoUsuario!);
              }
            } catch (e) {
              // Ignora erro ao obter URL da foto
            }
          }
          
          await accountManager.saveAccount(
            userId: response.user!.id,
            email: response.user!.email ?? _loginEmailController.text.trim(),
            nome: perfil.nome,
            fotoUrl: fotoUrl,
            tipo: perfil.tipo,
          );
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MainNavigatorScreen(perfil: perfil)),
            (_) => false,
          );
        } else {
          _showSnack('Perfil não encontrado.');
        }
      } else {
        _showSnack('Credenciais inválidas.');
      }
    } catch (e) {
      final errorMessage = e is AppException
          ? e.message
          : 'Erro ao fazer login: $e';
      _showSnack(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
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
        _registerPageController.jumpToPage(0);
        return;
      }
      if (password.length < 6 || password != confirm) {
        _showSnack('Verifique as senhas.');
        _registerPageController.jumpToPage(1);
        return;
      }
      if (!_termsAccepted) {
        _showSnack('Aceite os termos para continuar.');
        _registerPageController.jumpToPage(2);
        return;
      }
      if (!_consentimentoDadosSaude) {
        _showSnack('Você precisa consentir o compartilhamento de dados de saúde.');
        _registerPageController.jumpToPage(2);
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
          // Salvar informações da conta para troca rápida
          final accountManager = AccountManagerService();
          String? fotoUrl;
          if (perfil.fotoUsuario != null && perfil.fotoUsuario!.isNotEmpty) {
            try {
              if (perfil.fotoUsuario!.startsWith('http')) {
                fotoUrl = perfil.fotoUsuario;
              } else {
                fotoUrl = supabaseService.client.storage
                    .from('avatars')
                    .getPublicUrl(perfil.fotoUsuario!);
              }
            } catch (e) {
              // Ignora erro ao obter URL da foto
            }
          }
          
          await accountManager.saveAccount(
            userId: response.user!.id,
            email: response.user!.email ?? email,
            nome: perfil.nome,
            fotoUrl: fotoUrl,
            tipo: perfil.tipo,
          );
          
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
      final errorMessage = e is AppException
          ? e.message
          : 'Erro ao cadastrar: $e';
      _showSnack(errorMessage);
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

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Recuperar Senha',
          style: GoogleFonts.leagueSpartan(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Digite seu e-mail para receber instruções de redefinição de senha.',
              style: GoogleFonts.leagueSpartan(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-mail',
                hintText: 'seu@email.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.leagueSpartan(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (emailController.text.trim().isNotEmpty && 
                  emailController.text.contains('@')) {
                Navigator.pop(context, emailController.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, digite um e-mail válido'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0400BA),
            ),
            child: Text(
              'Enviar',
              style: GoogleFonts.leagueSpartan(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == null || result == false) return;

    final email = result as String;
    
    try {
      final supabaseService = getIt<SupabaseService>();
      await supabaseService.resetPassword(email);
      
      if (mounted) {
        _showSnack('Verifique seu e-mail para redefinir a senha');
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e is AppException
            ? e.message
            : 'Erro ao enviar e-mail de recuperação: $e';
        _showSnack(errorMessage);
      }
    }
  }

  void _nextPage() => _registerPageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );

  void _previousPage() => _registerPageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );

  // ==================== GLASSMORPHISM ====================

  Widget _glassContainer({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = MediaQuery.of(context).size.width;
        final screenH = MediaQuery.of(context).size.height;
        final pad = (screenW * 0.025).clamp(16.0, 28.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.white.withValues(alpha: 0.08))),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  width: screenW * 0.85,
                  constraints: BoxConstraints(maxWidth: 380, minHeight: 0, maxHeight: screenH * 0.8),
                  padding: EdgeInsets.all(pad),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
                    boxShadow: const [
                      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.15), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  foregroundDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.08), Colors.transparent],
                      stops: const [0.0, 0.2, 0.6],
                    ),
                  ),
                  child: child,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.white.withValues(alpha: 0.5), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 18,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0F000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return const Color(0xFF0600E0);
            return baseColor;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
          elevation: WidgetStateProperty.all(6),
          shadowColor: WidgetStateProperty.all(baseColor.withValues(alpha: 0.2)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          textStyle: WidgetStateProperty.all(GoogleFonts.leagueSpartan(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
          side: BorderSide(color: onPressed == null ? Colors.grey[400]! : Colors.white, width: 1.5),
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.leagueSpartan(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        child: Text(label, style: GoogleFonts.leagueSpartan(color: onPressed == null ? Colors.grey[400] : Colors.white)),
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
        style: GoogleFonts.leagueSpartan(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.leagueSpartan(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ==================== ACCOUNT OPTION (ANTES DOS STEPS) ====================

  Widget _accountOption(String title, String subtitle, String value) {
    final isSelected = _selectedAccountType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccountType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF0400BA) : Colors.white.withValues(alpha: 0.3), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedAccountType,
              onChanged: (v) => setState(() => _selectedAccountType = v!),
              activeColor: const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _linkSpan(String text, VoidCallback onTap) {
    return TextSpan(
      text: text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }

  // ==================== STEPS ====================

  Widget _buildStep1() {
    return Form(
      key: _registerFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _glowField(controller: _nameController, hint: 'Seu nome completo', validator: (v) => v?.trim().isEmpty ?? true ? 'Informe seu nome' : null),
          _glowField(controller: _emailController, hint: 'seu@email.com', keyboardType: TextInputType.emailAddress, validator: (v) => v == null || !v.contains('@') ? 'Email inválido' : null),
          const SizedBox(height: 8),
          _primaryButton(label: 'Continuar', onPressed: () => _registerFormKey.currentState!.validate() ? _nextPage() : null),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Crie sua senha', style: GoogleFonts.leagueSpartan(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _glowField(controller: _passwordController, hint: 'Mínimo 6 caracteres', obscure: true, validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null),
          _glowField(controller: _confirmPasswordController, hint: 'Repita a senha', obscure: true, validator: (v) => v != _passwordController.text ? 'Senhas não coincidem' : null),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _outlineButton(label: 'Voltar', onPressed: _previousPage)),
              const SizedBox(width: 12),
              Expanded(child: _primaryButton(label: 'Continuar', onPressed: () => _passwordFormKey.currentState!.validate() ? _nextPage() : null)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tipo de Conta', style: GoogleFonts.leagueSpartan(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _accountOption('Uso Pessoal', 'Para cuidar de você mesmo', 'pessoal'),
        const SizedBox(height: 12),
        _accountOption('Familiar/Cuidador', 'Para cuidar de um familiar ou pessoa próxima', 'familiar'),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              activeColor: const Color(0xFF0400BA),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  children: [
                    const TextSpan(text: 'Eu concordo com os '),
                    _linkSpan('Termos de Uso', () => _launchURL('https://www.caremind.online/termos')),
                    const TextSpan(text: ' e '),
                    _linkSpan('Política de Privacidade', () => _launchURL('https://www.caremind.online/politica-privacidade')),
                    const TextSpan(text: ' do CareMind.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Checkbox de consentimento LGPD para compartilhamento de dados de saúde
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _consentimentoDadosSaude,
              onChanged: (v) => setState(() => _consentimentoDadosSaude = v ?? false),
              activeColor: const Color(0xFF0400BA),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  children: [
                    const TextSpan(
                      text: 'Eu consinto o compartilhamento dos meus dados de saúde (medicamentos e compromissos) com familiares vinculados, conforme a ',
                    ),
                    _linkSpan('Política de Privacidade', () => _launchURL('https://www.caremind.online/politica-privacidade')),
                    const TextSpan(text: ' e a LGPD. Posso revogar este consentimento a qualquer momento nas configurações.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _outlineButton(label: 'Voltar', onPressed: _previousPage)),
            const SizedBox(width: 12),
            Expanded(
              child: _primaryButton(
                label: _isRegistering ? 'Criando conta...' : 'Finalizar',
                onPressed: (!_isRegistering && _termsAccepted && _consentimentoDadosSaude) ? _handleSignUp : null,
                isLoading: _isRegistering,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== CARDS ====================

  Widget _buildLoginCard() {
    return _glassContainer(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bem-vindo de volta!', style: GoogleFonts.leagueSpartan(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Faça login para continuar', style: GoogleFonts.leagueSpartan(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            _glowField(controller: _loginEmailController, hint: 'seu@email.com', keyboardType: TextInputType.emailAddress, validator: (v) => v?.contains('@') == true ? null : 'Email inválido'),
            _glowField(controller: _loginPasswordController, hint: 'Sua senha', obscure: true, validator: (v) => v?.isNotEmpty == true ? null : 'Informe a senha'),
            const SizedBox(height: 8),
            _primaryButton(label: 'Entrar', onPressed: _isLoginLoading ? null : _handleLogin, isLoading: _isLoginLoading),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoginLoading ? null : _handleForgotPassword,
              child: const Text(
                'Esqueceu a senha?',
                style: TextStyle(
                  color: Colors.white70,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            TextButton(
              onPressed: _isLoginLoading ? null : () => setState(() => _mode = AuthMode.register),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Não tem conta? '),
                    TextSpan(text: 'Cadastre-se', style: GoogleFonts.leagueSpartan(fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _glassContainer(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 0,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text('Criar Conta', style: GoogleFonts.leagueSpartan(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    Text('Passo ${_registerStep + 1} de 3', style: GoogleFonts.leagueSpartan(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 16),
                    // Conteúdo do passo atual
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: PageView(
                          controller: _registerPageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (i) => setState(() => _registerStep = i),
                          children: [
                            _buildStep1(),
                            _buildStep2(),
                            _buildStep3(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SmoothPageIndicator(
                      controller: _registerPageController,
                      count: 3,
                      effect: const WormEffect(
                        dotHeight: 6,
                        dotWidth: 6,
                        activeDotColor: Colors.white,
                        dotColor: Color.fromRGBO(255, 255, 255, 0.3),
                        spacing: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextButton(
                        onPressed: () => setState(() => _mode = AuthMode.login),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            children: [
                              const TextSpan(text: 'Já tem conta? '),
                              TextSpan(
                                text: 'Faça login',
                                style: GoogleFonts.leagueSpartan(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
            ),
          ),
        );
      },
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final logoHeight = (screenW * 0.18).clamp(70.0, 110.0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Fundo gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFA8B8FF), Color(0xFF9B7EFF)],
              ),
            ),
          ),

          // Ondas animadas (seu código perfeito)
          const Align(
            alignment: Alignment.bottomCenter,
            child: AuthWaveBackground(),
          ),

          // CONTEÚDO CENTRALIZADO
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: screenH * 0.08),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/caremind_deitado.png',
                    height: logoHeight,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),

                  // Card responsivo e centralizado
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: _mode == AuthMode.login
                        ? _buildLoginCard()
                        : _buildRegisterCard(),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}