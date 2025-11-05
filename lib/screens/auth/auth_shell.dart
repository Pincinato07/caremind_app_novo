import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/wave_background.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../services/supabase_service.dart';
import '../shared/main_navigator_screen.dart';

enum AuthMode { login, register }

class AuthShell extends StatefulWidget {
  const AuthShell({super.key, this.initialMode = AuthMode.login});

  final AuthMode initialMode;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  late AuthMode _mode;

  // Login controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _isLoginLoading = false;

  // Register controllers and state
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

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoginLoading = true);
    try {
      final response = await SupabaseService.signIn(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (!mounted) return;
      if (response.user != null) {
        final perfil = await SupabaseService.getProfile(response.user!.id);
        if (perfil != null && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MainNavigatorScreen(perfil: perfil)),
            (route) => false,
          );
        } else {
          _showSnack('Não foi possível carregar seu perfil.');
        }
      } else {
        _showSnack('Erro ao fazer login.');
      }
    } catch (e) {
      _showSnack('Erro: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    // Validate all forms - check if currentState is not null first
    final registerFormValid = _registerFormKey.currentState?.validate() ?? false;
    final passwordFormValid = _passwordFormKey.currentState?.validate() ?? false;

    if (!registerFormValid || !passwordFormValid || !_termsAccepted) {
      _showSnack('Por favor, preencha todos os campos corretamente.');
      return;
    }

    if (!mounted) return;

    try {
      final response = await SupabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nome: _nameController.text.trim(),
        tipo: _selectedAccountType,
      );

      if (response.user != null && mounted) {
        // Create profile immediately after signup
        await SupabaseService.createProfile(
          userId: response.user!.id,
          nome: _nameController.text.trim(),
          tipo: _selectedAccountType,
        );

        // Aguardar um pouco para garantir que o perfil seja criado
        await Future.delayed(const Duration(seconds: 1));

        final perfil = await SupabaseService.getProfile(response.user!.id);
        if (perfil != null && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MainNavigatorScreen(perfil: perfil)),
            (route) => false,
          );
        } else if (mounted) {
          _showSnack('Cadastro realizado com sucesso! Faça login para continuar.');
          setState(() => _mode = AuthMode.login);
        }
      } else if (mounted) {
        _showSnack('Erro ao realizar cadastro. Tente novamente.');
      }
    } catch (e) {
      // Trata erros de registro
      if (mounted) {
        _showSnack('Erro ao criar conta: ${e.toString()}');
      }
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
  
  // Step 1: Personal Information
  Widget _buildStep1() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nome Completo',
            style: GoogleFonts.leagueSpartan(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.25,
              shadows: [Shadow(color: Colors.black.withOpacity(0.2), offset: Offset(0, 2), blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 8),
          _glowField(
            controller: _nameController,
            hint: 'Seu nome',
            validator: (v) => v == null || v.isEmpty ? 'Informe seu nome' : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Email',
            style: GoogleFonts.leagueSpartan(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.25,
              shadows: [Shadow(color: Colors.black.withOpacity(0.2), offset: Offset(0, 2), blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 8),
          _glowField(
            controller: _emailController,
            hint: 'seu@email.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v == null || v.isEmpty
                ? 'Informe o e-mail'
                : !v.contains('@')
                    ? 'E-mail inválido'
                    : null,
          ),
          const Spacer(),
          _primaryButton(
            label: 'Continuar',
            onPressed: () {
              if (_registerFormKey.currentState!.validate()) {
                _registerPageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _registerStep = 1);
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  // Step 2: Password
  Widget _buildStep2() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Crie sua senha',
            style: GoogleFonts.leagueSpartan(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.25,
              shadows: [Shadow(color: Colors.black.withOpacity(0.2), offset: Offset(0, 2), blurRadius: 4)],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Senha',
            style: GoogleFonts.leagueSpartan(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          _glowField(
            controller: _passwordController,
            hint: 'Digite sua senha',
            obscure: true,
            validator: (v) => v == null || v.isEmpty
                ? 'Informe uma senha'
                : v.length < 6
                    ? 'A senha deve ter no mínimo 6 caracteres'
                    : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Confirmar Senha',
            style: GoogleFonts.leagueSpartan(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          _glowField(
            controller: _confirmPasswordController,
            hint: 'Confirme sua senha',
            obscure: true,
            validator: (v) => v == null || v.isEmpty
                ? 'Confirme sua senha'
                : v != _passwordController.text
                    ? 'As senhas não conferem'
                    : null,
          ),
          const Spacer(),
          const SizedBox(height: 24), // Extra space before buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _registerPageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    setState(() => _registerStep = 0);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.1), // Add background for visibility
                  ),
                  child: const Text('Voltar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _primaryButton(
                  label: 'Continuar',
                  onPressed: () {
                    if (_passwordFormKey.currentState!.validate()) {
                      _registerPageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _registerStep = 2);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  // Step 3: Account Type
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Como você usará o Caremind?',
          style: GoogleFonts.leagueSpartan(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.25,
            shadows: [const Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildAccountTypeOption(
                  title: 'Uso Pessoal',
                  subtitle: 'Para gerenciar meus próprios medicamentos',
                  value: 'pessoal',
                  groupValue: _selectedAccountType,
                  onChanged: (value) => setState(() => _selectedAccountType = value!),
                ),
                const SizedBox(height: 12),
                _buildAccountTypeOption(
                  title: 'Familiar / Cuidador',
                  subtitle: 'Para cuidar de um familiar ou paciente',
                  value: 'cuidador',
                  groupValue: _selectedAccountType,
                  onChanged: (value) => setState(() => _selectedAccountType = value!),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                      children: [
                        const TextSpan(text: 'Eu concordo com os '),
                        TextSpan(
                          text: 'Termos de Uso',
                          style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // TODO: Open terms and conditions
                            },
                        ),
                        const TextSpan(text: ' e '),
                        TextSpan(
                          text: 'Política de Privacidade',
                          style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // TODO: Open privacy policy
                            },
                        ),
                        const TextSpan(text: ' do Caremind.'),
                      ],
                    ),
                  ),
                  value: _termsAccepted,
                  onChanged: (value) => setState(() => _termsAccepted = value ?? false),
                  activeColor: const Color(0xFF0400BA),
                  checkColor: Colors.white,
                  controlAffinity: ListTileControlAffinity.leading,
                  tileColor: Colors.transparent,
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _registerPageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  setState(() => _registerStep = 1);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.1), // Add background for visibility
                ),
                child: const Text('Voltar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _primaryButton(
                label: 'Finalizar Cadastro',
                onPressed: _termsAccepted ? _handleSignUp : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _buildAccountTypeOption({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: groupValue == value 
              ? const Color(0xFF0400BA).withOpacity(0.8) 
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: RadioListTile<String>(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
        ),
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: const Color(0xFF0400BA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
        tileColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Softer left-to-right background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFA8B8FF), Color(0xFF9B7EFF)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          // Global animated waves (match CSS-like layers)
          Align(
            alignment: Alignment.bottomCenter,
            child: const SizedBox(
              key: ValueKey('auth_waves_v3'),
              child: AuthWaveBackground(),
            ),
          ),
          // Top logo (global)
          SafeArea(
            child: Stack(
              children: [
                // Logo caremind_deitado.png alinhado acima do card
                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: Builder(builder: (context) {
                    final w = MediaQuery.of(context).size.width;
                    final double height = (w * 0.15).clamp(40.0, 80.0);
                    return Image.asset(
                      'assets/images/caremind_deitado.png',
                      height: height,
                      fit: BoxFit.contain,
                    );
                  }),
                ),
                // Animated card switcher (only the card changes)
                Positioned.fill(
                  child: Align(
                    // Raise the card closer to center
                    alignment: const Alignment(0, 0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) {
                          // Fade + slight vertical slide
                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          );
                        },
                        child: _mode == AuthMode.login
                            ? _buildLoginCard(key: const ValueKey('login'))
                            : _buildRegisterCard(key: const ValueKey('register')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Primary solid button per spec (shadow + 48px height)
  Widget _primaryButton({required String label, required VoidCallback? onPressed}) {
    final baseColor = const Color(0xFF0400BA);
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 300),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF020054); // 20% darker approx
            }
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
              return const Color(0xFF0600E0); // 10% darker/active
            }
            return baseColor;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.06)),
          elevation: WidgetStateProperty.all(6),
          shadowColor: WidgetStateProperty.all(baseColor.withOpacity(0.2)),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        child: Text(label),
      ),
    );
  }

  // Card container (glassmorphism)
  Widget _glassContainer({required Widget child, Key? key}) {
    return KeyedSubtree(
      key: key,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = MediaQuery.of(context).size.width;
          final pad = (screenW * 0.025).clamp(16.0, 28.0);
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Neutral underlay so the BackdropFilter doesn't pick strong hues from the page gradient
                // This keeps the gradient behind the card without tinting the glass excessively
                Positioned.fill(
                  child: Container(color: Colors.white.withOpacity(0.08)),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    width: screenW * 0.85,
                    constraints: const BoxConstraints(maxWidth: 380),
                    padding: EdgeInsets.all(pad),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                      boxShadow: const [
                        // subtle outer shadow around edges
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.15),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    foregroundDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.2, 0.6],
                      ),
                    ),
                    child: child,
                  ),
                ),
                // Top 1px glow line
                Positioned(
                  top: 0,
                  right: 0,
                  left: 0,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Subtle inner shadow at bottom
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
                          colors: [
                            Color(0x0F000000),
                            Color(0x00000000),
                          ]
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper: responsive title size (clamp)
  Text _responsiveTitle(String text) {
    final w = MediaQuery.of(context).size.width;
    final size = (w * 0.06).clamp(28.0, 48.0);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.leagueSpartan(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: Colors.white,
        shadows: [Shadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 2), blurRadius: 4)],
      ),
    );
  }

  // Helper: solid field (no glow)
  Widget _glowField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Color(0xFF2D3748)),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildLoginCard({Key? key}) {
    return _glassContainer(
      key: key,
      child: Form(
        key: _loginFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _responsiveTitle('Entrar'),
            const SizedBox(height: 24),
            Text(
              'Email',
              style: GoogleFonts.leagueSpartan(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.25,
                shadows: [Shadow(color: Colors.black.withOpacity(0.2), offset: Offset(0, 2), blurRadius: 4)],
              ),
            ),
            const SizedBox(height: 8),
            _glowField(
              controller: _loginEmailController,
              hint: 'seu@email.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Informe o e-mail' : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Senha',
              style: GoogleFonts.leagueSpartan(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.25,
                shadows: [Shadow(color: Colors.black.withOpacity(0.2), offset: Offset(0, 2), blurRadius: 4)],
              ),
            ),
            const SizedBox(height: 8),
            _glowField(
              controller: _loginPasswordController,
              hint: 'Password',
              obscure: true,
              validator: (v) => v == null || v.isEmpty ? 'Informe a senha' : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Esqueci minha senha',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white70,
                  decorationThickness: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _isLoginLoading
                ? const SizedBox(height: 48, child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0400BA)))))
                : _primaryButton(label: 'Entrar', onPressed: _handleLogin),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não tem conta ainda? ', style: TextStyle(color: Colors.white, fontSize: 14)),
                  GestureDetector(
                    onTap: () => setState(() => _mode = AuthMode.register),
                    child: const Text('Criar conta', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.black12),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterCard({Key? key}) {
    return _glassContainer(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _responsiveTitle('Registrar'),
          const SizedBox(height: 6),
          Text(
            'Passo ${_registerStep + 1} de 3',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Page indicator
          Center(
            child: SmoothPageIndicator(
              controller: _registerPageController,
              count: 3,
              effect: WormEffect(
                dotWidth: 8,
                dotHeight: 8,
                activeDotColor: Colors.white,
                dotColor: Colors.white.withOpacity(0.3),
                spacing: 6,
              ),
              onDotClicked: (index) {
                _registerPageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _registerStep = index);
              },
            ),
          ),
          const SizedBox(height: 16),
          // PageView for the registration steps
          SizedBox(
            height: 320, // Increased height to give more space for buttons in step 2
            child: PageView(
              controller: _registerPageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _registerStep = index);
              },
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
          // Bottom links - only show on step 0 and attach to bottom
          if (_registerStep == 0) ...[
            const SizedBox(height: 4), // Very minimal spacing
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Já tem uma conta? ', style: TextStyle(color: Colors.white, fontSize: 14)),
                  GestureDetector(
                    onTap: () => setState(() => _mode = AuthMode.login),
                    child: const Text(
                      'Fazer login',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
