import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import 'main_navigator_screen.dart';
import '../../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final String tipo;

  const AuthScreen({super.key, required this.tipo});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  // Chaves dos formulários
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  
  // Controllers para os campos
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Estados da UI
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLogin = true;
  bool _isKeyboardVisible = false;
  
  // Animações
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));
    
    _animationController.forward();
    
    // Verificar se o teclado está visível
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewInsets = MediaQuery.of(context).viewInsets.bottom;
      setState(() {
        _isKeyboardVisible = viewInsets > 0;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nomeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _animationController.reset();
      _animationController.forward();
      
      // Limpa os campos ao alternar entre login e registro
      if (_isLogin) {
        _nomeController.clear();
      }
    });
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nome: _nomeController.text.trim(),
        tipo: widget.tipo,
      );

      if (response.user != null) {
        await _redirectToDashboard(response.user!.id);
      } else {
        _showError('Erro ao criar conta. Tente novamente.');
      }
    } catch (error) {
      _showError('Erro ao criar conta: ${error.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        await _redirectToDashboard(response.user!.id);
      } else {
        _showError('Erro ao fazer login. Verifique suas credenciais.');
      }
    } catch (error) {
      _showError('Erro ao fazer login: ${error.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _redirectToDashboard(String userId) async {
    try {
      // Buscamos o perfil completo do usuário
      final perfil = await SupabaseService.getProfile(userId);
      
      if (perfil != null && perfil.tipo != null && mounted) {
        // Navegamos para a nova tela navigator, passando o perfil como argumento
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigatorScreen(perfil: perfil),
          ),
          (route) => false, // Remove todas as rotas anteriores
        );
      } else {
        // Tratamento de erro caso o perfil não seja encontrado
        _showError('Erro ao carregar o perfil do usuário.');
      }
    } catch (error) {
      _showError('Erro ao redirecionar: ${error.toString()}');
    }
  }

  void _showError(String message) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onError,
          ),
        ),
        backgroundColor: colors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumAll,
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: colors.background,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: colors.onBackground),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.primary.withOpacity(0.05),
                colors.surface.withOpacity(0.8),
                colors.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - MediaQuery.of(context).padding.vertical,
                ),
                child: Column(
                  children: [
                    // Cabeçalho com animação
                    if (!_isKeyboardVisible) ..._buildHeader(theme, colors),
                    
                    // Formulário com animação de transição
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.1, 0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutQuad,
                              )),
                              child: child,
                            ),
                          );
                        },
                        child: _isLogin 
                            ? _buildLoginForm(theme, colors)
                            : _buildRegisterForm(theme, colors),
                      ),
                    ),
                    
                    // Botão de alternar entre login/cadastro
                    if (!_isKeyboardVisible) ..._buildAuthToggle(theme, colors),
                    
                    // Rodapé com redes sociais
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  List<Widget> _buildHeader(ThemeData theme, ColorScheme colors) {
    return [
      const SizedBox(height: 20),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Hero(
          key: ValueKey<bool>(_isLogin),
          tag: 'app_logo',
          child: Container(
            width: 120,
            height: 120,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/caremind.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          _isLogin ? 'Bem-vindo de volta!' : 'Vamos começar',
          key: ValueKey<String>('title_${_isLogin ? 'login' : 'register'}'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Padding(
          key: ValueKey<String>('subtitle_${_isLogin ? 'login' : 'register'}'),
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            _isLogin 
                ? 'Entre para continuar cuidando da sua saúde' 
                : 'Crie sua conta para começar a usar o CareMind',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      const SizedBox(height: 32),
    ];
  }
  
  List<Widget> _buildAuthToggle(ThemeData theme, ColorScheme colors) {
    return [
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isLogin ? 'Não tem uma conta? ' : 'Já tem uma conta? ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleAuthMode,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  _isLogin ? 'Criar conta' : 'Fazer login',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }
  

  Widget _buildLoginForm(ThemeData theme, ColorScheme colors) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEmailField(theme, colors),
          const SizedBox(height: 16),
          _buildPasswordField(theme, colors),
          const SizedBox(height: 40),
          // Botão Entrar
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.mediumAll,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Entrar',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // Espaço para o botão de alternar entre login/cadastro que já está sendo exibido no final
        ],
      ),
    );
  }

  Widget _buildRegisterForm(ThemeData theme, ColorScheme colors) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Campo Nome
          Container(
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumAll,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              controller: _nomeController,
              keyboardType: TextInputType.name,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Nome Completo',
                labelStyle: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: AppBorderRadius.smallAll,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: AppBorderRadius.mediumAll,
                  borderSide: BorderSide(color: colors.outline.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppBorderRadius.mediumAll,
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppBorderRadius.mediumAll,
                  borderSide: BorderSide(color: colors.outline.withOpacity(0.3)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira seu nome completo';
                }
                if (value.length < 3) {
                  return 'O nome deve ter pelo menos 3 caracteres';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildEmailField(theme, colors),
          const SizedBox(height: 16),
          _buildPasswordField(theme, colors),
          const SizedBox(height: 32),
          // Termos e condições
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, -2),
                child: Checkbox(
                  value: true,
                  onChanged: (value) {},
                  activeColor: colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Ao se registrar, você concorda com nossos Termos de Serviço e Política de Privacidade',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Botão de Cadastrar
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.mediumAll,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_add, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Cadastrar',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Já tem uma conta? ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              GestureDetector(
                onTap: _toggleAuthMode,
                child: Text(
                  'Fazer login',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(ThemeData theme, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppBorderRadius.mediumAll,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: colors.onSurface,
        ),
        decoration: InputDecoration(
          labelText: 'E-mail',
          labelStyle: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: AppBorderRadius.smallAll,
            ),
            child: Icon(
              Icons.email_outlined,
              color: colors.primary,
              size: 20,
            ),
          ),
          filled: true,
          fillColor: colors.surface,
          border: OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumAll,
            borderSide: BorderSide(color: colors.outline.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumAll,
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumAll,
            borderSide: BorderSide(color: colors.outline.withOpacity(0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Por favor, insira seu e-mail';
          }
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
            return 'Por favor, insira um e-mail válido';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppBorderRadius.mediumAll,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: colors.onSurface,
        ),
        decoration: InputDecoration(
          labelText: 'Senha',
          labelStyle: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: AppBorderRadius.smallAll,
            ),
            child: Icon(
              Icons.lock_outlined,
              color: colors.primary,
              size: 20,
            ),
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceVariant.withOpacity(0.5),
              borderRadius: AppBorderRadius.smallAll,
            ),
            child: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          filled: true,
          fillColor: colors.surface,
          border: OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumAll,
            borderSide: BorderSide(color: colors.outline.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumAll,
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumAll,
            borderSide: BorderSide(color: colors.outline.withOpacity(0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Por favor, insira sua senha';
          }
          if (value.length < 6) {
            return 'A senha deve ter pelo menos 6 caracteres';
          }
          return null;
        },
      ),
    );
  }
}