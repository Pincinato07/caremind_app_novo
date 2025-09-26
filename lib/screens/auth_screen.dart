import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:caremind/screens/main_navigator_screen.dart';
import 'package:caremind/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final String tipo;

  const AuthScreen({super.key, required this.tipo});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  
  // Controllers para os campos
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.1),
            borderRadius: AppBorderRadius.mediumAll,
            border: Border.all(
              color: colors.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: colors.primary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary.withOpacity(0.1),
                colors.primaryContainer.withOpacity(0.05),
              ],
            ),
            borderRadius: AppBorderRadius.largeAll,
            border: Border.all(
              color: colors.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            widget.tipo == 'individual' ? 'Uso Individual' : 'Plano Família',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.05),
              borderRadius: AppBorderRadius.largeAll,
              border: Border.all(
                color: colors.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: colors.onPrimary,
              unselectedLabelColor: colors.primary,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.primaryContainer],
                ),
                borderRadius: AppBorderRadius.mediumAll,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Entrar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Registrar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLoginTab(),
          _buildRegisterTab(),
        ],
      ),
    );
  }

  Widget _buildLoginTab() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Center(
      child: Container(
        constraints: const BoxConstraints(minHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _loginFormKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                
                Text(
                  'Bem-vindo de volta!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Entre com sua conta para continuar',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
            
                // Campo E-mail
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
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Por favor, insira um e-mail válido';
                      }
                      return null;
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Campo Senha
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
                      return null;
                    },
                  ),
                ),
                
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
                
                // Link para criar conta
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Não tem uma conta? ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _tabController.animateTo(1);
                      },
                      child: Text(
                        'Criar agora',
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
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterTab() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Center(
      child: Container(
        constraints: const BoxConstraints(minHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _registerFormKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                
                Text(
                  'Criar nova conta',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Preencha os dados para começar',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
            
                // Campo Nome
                TextFormField(
                  controller: _nomeController,
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
                        Icons.person_outlined,
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
                      return 'Nome deve ter pelo menos 3 caracteres';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Campo E-mail
                TextFormField(
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
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Por favor, insira um e-mail válido';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Campo Senha
                TextFormField(
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
                      return 'Por favor, insira uma senha';
                    }
                    if (value.length < 6) {
                      return 'Senha deve ter pelo menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Botão Registrar
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
                                'Registrar',
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
                
                // Link para fazer login
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
                      onTap: () {
                        _tabController.animateTo(0);
                      },
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
          ),
        ),
      ),
    );
  }
}