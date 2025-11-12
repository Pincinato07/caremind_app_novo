import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../widgets/wave_background.dart';
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

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    
    // Adicionar listeners para depuração
    _nameController.addListener(() {
      print('Nome alterado para: ${_nameController.text}');
    });
    
    _emailController.addListener(() {
      print('Email alterado para: ${_emailController.text}');
    });
    
    print('=== INIT STATE ===');
    print('_registerFormKey: $_registerFormKey');
    print('_passwordFormKey: $_passwordFormKey');
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
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Não foi possível abrir o link: $url');
    }
  }

  // ==================== AUTH HANDLERS ====================

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
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
          _showSnack('Perfil não encontrado.');
        }
      } else {
        _showSnack('Credenciais inválidas.');
      }
    } catch (e) {
      _showSnack('Erro: $e');
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    print('=== MÉTODO _handleSignUp CHAMADO ===');
    
    // Debug: Mostrar estado dos campos
    debugPrint('\n=== DEBUG - ESTADO DOS CAMPOS ===');
    debugPrint('Nome: "${_nameController.text}" (${_nameController.text.length} caracteres)');
    debugPrint('Email: "${_emailController.text}" (${_emailController.text.length} caracteres)');
    debugPrint('Senha: ${_passwordController.text.isNotEmpty ? "[PREENCHIDO]" : "[VAZIO]"}');
    debugPrint('Confirmar Senha: ${_confirmPasswordController.text.isNotEmpty ? "[PREENCHIDO]" : "[VAZIO]"}');
    debugPrint('Tipo de Conta: $_selectedAccountType');
    debugPrint('Termos Aceitos: $_termsAccepted');
    
    // Validação manual dos campos do passo 1
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    
    // Validar campos do passo 1
    bool step1Valid = name.isNotEmpty && email.contains('@');
    debugPrint('\n=== VALIDAÇÃO PASSO 1 ===');
    debugPrint('Validação Nome: ${name.isNotEmpty}');
    debugPrint('Validação Email: ${email.contains('@')}');
    debugPrint('Validação do Passo 1 finalizada. Resultado: $step1Valid');
    
    // Validar campos do passo 2
    bool step2Valid = password.length >= 6 && password == confirmPassword;
    debugPrint('\n=== VALIDAÇÃO PASSO 2 ===');
    debugPrint('Validação Tamanho Senha: ${password.length >= 6}');
    debugPrint('Validação Confirmação: ${password == confirmPassword}');
    debugPrint('Validação do Passo 2 finalizada. Resultado: $step2Valid');

    // Debug: Mostrar o estado das validações
    debugPrint('\n=== RESUMO DAS VALIDAÇÕES ===');
    debugPrint('Passo 1 (Nome e Email): $step1Valid');
    debugPrint('Passo 2 (Senhas): $step2Valid');
    debugPrint('Termos aceitos: $_termsAccepted');

    if (!step1Valid) {
      debugPrint('Falha na validação do Passo 1. Navegando para a página 0...');
      _showSnack('Por favor, preencha corretamente os dados do primeiro passo.');
      _registerPageController.jumpToPage(0);
      return;
    }

    if (!step2Valid) {
      _showSnack('Por favor, verifique as senhas informadas.');
      _registerPageController.jumpToPage(1);
      return;
    }

    if (!_termsAccepted) {
      _showSnack('Você precisa aceitar os termos de uso para continuar.');
      _registerPageController.jumpToPage(2);
      return;
    }

    try {
      final response = await SupabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nome: _nameController.text.trim(),
        tipo: _selectedAccountType,
      );

      if (!mounted) return;

      if (response.user != null) {
        // O trigger 'handle_new_user' no Supabase já criou o perfil automaticamente
        // usando os metadados que enviamos no 'signUp'.
        
        // Adicionamos um pequeno delay para dar tempo ao trigger de rodar
        await Future.delayed(const Duration(milliseconds: 500));

        final perfil = await SupabaseService.getProfile(response.user!.id);
        if (perfil != null && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MainNavigatorScreen(perfil: perfil)),
            (route) => false,
          );
        } else {
          // O trigger pode ter falhado ou o RLS está bloqueando
          _showSnack('Erro ao carregar seu novo perfil. Tente fazer login.');
          setState(() => _mode = AuthMode.login);
        }
      }
    } catch (e) {
      _showSnack('Erro ao cadastrar: $e');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ==================== NAVIGATION ====================

  void _nextPage() {
    _registerPageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  void _previousPage() {
    _registerPageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  // ==================== STEP BUILDERS ====================

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _fieldLabel('Nome Completo'),
            const SizedBox(height: 8),
            _glowField(
              controller: _nameController,
              hint: 'Seu nome completo',
              validator: (v) => v?.trim().isEmpty ?? true ? 'Informe seu nome' : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Email'),
            const SizedBox(height: 8),
            _glowField(
              controller: _emailController,
              hint: 'seu@email.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || !v.contains('@') ? 'Email inválido' : null,
            ),
            const SizedBox(height: 24),
            _primaryButton(
              label: 'Continuar',
              onPressed: () {
                if (_registerFormKey.currentState!.validate()) {
                  _nextPage();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    print('=== _buildStep2 CHAMADO ===');
    print('_passwordController: ${_passwordController.text} (${_passwordController.text.length} caracteres)');
    print('_confirmPasswordController: ${_confirmPasswordController.text} (${_confirmPasswordController.text.length} caracteres)');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Crie sua senha',
              style: GoogleFonts.leagueSpartan(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _fieldLabel('Senha'),
            const SizedBox(height: 8),
            _glowField(
              controller: _passwordController,
              hint: 'Mínimo 6 caracteres',
              obscure: true,
              validator: (v) {
                final isValid = v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null;
                print('Validação Senha: ${isValid ?? 'VÁLIDA'}');
                return isValid;
              },
            ),
            const SizedBox(height: 16),
            _fieldLabel('Confirmar Senha'),
            const SizedBox(height: 8),
            _glowField(
              controller: _confirmPasswordController,
              hint: 'Repita a senha',
              obscure: true,
              validator: (v) {
                final isValid = v != _passwordController.text ? 'Senhas não coincidem' : null;
                print('Validação Confirmação: ${isValid ?? 'VÁLIDA'}');
                return isValid;
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _outlineButton(label: 'Voltar', onPressed: _previousPage)),
                const SizedBox(width: 12),
                Expanded(
                  child: _primaryButton(
                    label: 'Continuar',
                    onPressed: () {
                      print('=== BOTÃO CONTINUAR PRESSIONADO (PASSO 2) ===');
                      print('_passwordFormKey.currentState: ${_passwordFormKey.currentState}');
                      print('Senha: ${_passwordController.text}');
                      print('Confirmação: ${_confirmPasswordController.text}');
                      
                      if (_passwordFormKey.currentState != null) {
                        final isValid = _passwordFormKey.currentState!.validate();
                        print('Validação do formulário: $isValid');
                        
                        if (isValid) {
                          _nextPage();
                        } else {
                          print('Formulário inválido!');
                        }
                      } else {
                        print('ERRO: _passwordFormKey.currentState é nulo');
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    print('=== _buildStep3 CHAMADO ===');
    print('_termsAccepted: $_termsAccepted');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tipo de Conta',
            style: GoogleFonts.leagueSpartan(
              fontSize: 20, 
              fontWeight: FontWeight.w700, 
              color: Colors.white
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _accountOption(
            'Uso Pessoal',
            'Para cuidar de você mesmo',
            'pessoal',
          ),
          const SizedBox(height: 12),
          _accountOption(
            'Familiar/Cuidador',
            'Para cuidar de um familiar ou pessoa próxima',
            'familiar',
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _termsAccepted,
                onChanged: (v) {
                  print('Termos aceitos alterado para: $v');
                  setState(() {
                    _termsAccepted = v ?? false;
                    print('_termsAccepted atualizado para: $_termsAccepted');
                  });
                },
                activeColor: const Color(0xFF4CAF50),
                fillColor: MaterialStateProperty.resolveWith<Color>(
                  (states) => states.contains(MaterialState.selected) 
                    ? const Color(0xFF4CAF50) 
                    : Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withAlpha(230), 
                      fontSize: 14, 
                      height: 1.4
                    ),
                    children: [
                      const TextSpan(text: 'Eu concordo com os '),
                      _linkSpan(
                        'Termos de Uso', 
                        () => _launchURL('https://www.caremind.online/termos')
                      ),
                      const TextSpan(text: ' e '),
                      _linkSpan(
                        'Política de Privacidade', 
                        () => _launchURL('https://www.caremind.online/politica-privacidade')
                      ),
                      const TextSpan(text: ' do CareMind.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _outlineButton(
                  label: 'Voltar', 
                  onPressed: _previousPage, 
                  fontSize: 16
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _primaryButton(
                  label: 'Finalizar',
                  onPressed: _termsAccepted ? _handleSignUp : null,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountOption(String title, String subtitle, String value) {
    final isSelected = _selectedAccountType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccountType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.white.withAlpha(77),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedAccountType,
              onChanged: (v) => setState(() => _selectedAccountType = v!),
              activeColor: const Color(0xFF4CAF50),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 12, height: 1.2),
                    ),
                  ],
                ),
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
      style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }

  // ==================== UI HELPERS 
  // ====================

  Widget _fieldLabel(String text) {
    return Text(text, style: GoogleFonts.leagueSpartan(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600));
  }

  Widget _glowField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withAlpha(140)),
        filled: true,
        fillColor: Colors.white.withAlpha(20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withAlpha(50)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.amber),
      ),
      onChanged: (value) {
        print('Campo alterado ($hint): $value');
        if (_registerFormKey.currentState != null) {
          _registerFormKey.currentState!.validate();
        }
      },
      validator: validator,
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    double fontSize = 16,
    EdgeInsetsGeometry? padding,
  }) {
    print('=== _primaryButton chamado ===');
    print('Label: $label');
    print('onPressed: $onPressed');
    print('_termsAccepted: $_termsAccepted');
    
    return ElevatedButton(
      onPressed: onPressed == null 
          ? null 
          : () {
              print('Botão pressionado: $label');
              onPressed();
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null ? Colors.grey[400] : const Color(0xFF4CAF50),
        padding: padding ?? const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        minimumSize: const Size(double.infinity, 50),
      ),
      child: onPressed == _handleLogin && _isLoginLoading
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: GoogleFonts.leagueSpartan(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w600)),
    );
  }

  Widget _outlineButton({required String label, required VoidCallback onPressed, double fontSize = 16}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white.withAlpha(26),
      ),
      child: Text(
        label, 
        style: GoogleFonts.leagueSpartan(
          color: Colors.white, 
          fontSize: fontSize, 
          fontWeight: FontWeight.w600
        )
      ),
    );
  }

  Widget _glassContainer({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withAlpha(46)),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Text _responsiveTitle(String text) {
    final size = MediaQuery.of(context).size.width * 0.06;
    final clampedSize = size.clamp(24.0, 32.0);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.leagueSpartan(
        fontSize: clampedSize,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
    );
  }

  // ==================== MAIN BUILD ====================

  @override
  Widget build(BuildContext context) {
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
          
          // Ondas na parte inferior
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AuthWaveBackground(),
          ),

          // Conteúdo principal
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/images/caremind_deitado.png',
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 24),
                        
                        // Card de autenticação
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: _mode == AuthMode.login
                              ? _buildLoginCard()
                              : _buildRegisterCard(),
                        ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return _glassContainer(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _responsiveTitle('Bem-vindo de volta!'),
            const SizedBox(height: 8),
            Text(
              'Faça login para continuar',
              style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _fieldLabel('Email'),
            const SizedBox(height: 8),
            _glowField(
              controller: _loginEmailController,
              hint: 'seu@email.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v?.contains('@') == true ? null : 'Email inválido',
            ),
            const SizedBox(height: 16),
            _fieldLabel('Senha'),
            const SizedBox(height: 8),
            _glowField(
              controller: _loginPasswordController,
              hint: 'Sua senha',
              obscure: true,
              validator: (v) => v?.isNotEmpty == true ? null : 'Informe a senha',
            ),
            const SizedBox(height: 24),
            _primaryButton(
              label: 'Entrar',
              onPressed: _isLoginLoading ? null : _handleLogin,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _showSnack('Em breve'),
              child: const Text(
                'Esqueceu a senha?',
                style: TextStyle(
                  color: Colors.white70,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            TextButton(
              onPressed: _isLoginLoading
                  ? null
                  : () => setState(() => _mode = AuthMode.register),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white.withAlpha(230),
                    fontSize: 14,
                  ),
                  children: const [
                    TextSpan(text: 'Não tem conta? '),
                    TextSpan(
                      text: 'Cadastre-se',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
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
    return _glassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho
          _responsiveTitle('Criar Conta'),
          const SizedBox(height: 4),
          Text(
            'Passo ${_registerStep + 1} de 3',
            style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Conteúdo animado que se adapta ao tamanho
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SizedBox(
              height: _getStepHeight(),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {},
                child: PageView(
                  controller: _registerPageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) {
                    // Add a small delay to prevent animation glitches
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (mounted) {
                        setState(() => _registerStep = i);
                      }
                    });
                  },
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Indicador
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

          const SizedBox(height: 16),

          // Link para login (apenas no passo 1)
          if (_registerStep == 0)
            RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 14),
                children: [
                  const TextSpan(text: 'Já tem conta? '),
                  TextSpan(
                    text: 'Fazer login',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => setState(() => _mode = AuthMode.login),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 0),
        ],
      ),
    );
  }

  // Retorna a altura apropriada para cada passo
  double _getStepHeight() {
    switch (_registerStep) {
      case 0: // Step 1 - Nome e Email
        return 280.0;
      case 1: // Step 2 - Senhas
        return 300.0;
      case 2: // Step 3 - Tipo de conta e termos
        return 350.0;
      default:
        return 280.0;
    }
  }
}