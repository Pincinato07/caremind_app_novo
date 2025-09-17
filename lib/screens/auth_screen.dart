import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/perfil.dart';

class AuthScreen extends StatefulWidget {
  final String tipo;

  const AuthScreen({super.key, required this.tipo});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
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
    if (!_formKey.currentState!.validate()) return;

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
    if (!_formKey.currentState!.validate()) return;

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
      final perfil = await SupabaseService.getProfile(userId);
      
      if (perfil != null && perfil.tipo != null) {
        if (perfil.tipo == 'individual') {
          Navigator.pushReplacementNamed(context, '/individual-dashboard');
        } else if (perfil.tipo == 'familiar') {
          Navigator.pushReplacementNamed(context, '/familiar-dashboard');
        }
      } else {
        _showError('Erro ao carregar perfil do usuário.');
      }
    } catch (error) {
      _showError('Erro ao redirecionar: ${error.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAFA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF0400B9),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.tipo == 'individual' ? 'Uso Individual' : 'Plano Família',
          style: const TextStyle(
            color: Color(0xFF0400B9),
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0400B9),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0400B9),
          tabs: const [
            Tab(text: 'Entrar'),
            Tab(text: 'Registrar'),
          ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            
            const Text(
              'Bem-vindo de volta!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0400B9),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            const Text(
              'Entre com sua conta para continuar',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Campo E-mail
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-mail',
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF0400B9),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF0400B9), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
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
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(
                  Icons.lock_outlined,
                  color: Color(0xFF0400B9),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF0400B9), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira sua senha';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 40),

            // Botão Entrar
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0400B9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.login,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Entrar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            
            const Text(
              'Criar nova conta',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0400B9),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            const Text(
              'Preencha os dados para começar',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Campo Nome
            TextFormField(
              controller: _nomeController,
              decoration: InputDecoration(
                labelText: 'Nome Completo',
                prefixIcon: const Icon(
                  Icons.person_outlined,
                  color: Color(0xFF0400B9),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF0400B9), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
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
              decoration: InputDecoration(
                labelText: 'E-mail',
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF0400B9),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF0400B9), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
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
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(
                  Icons.lock_outlined,
                  color: Color(0xFF0400B9),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF0400B9), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
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
                  backgroundColor: const Color(0xFF0400B9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_add,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Registrar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
}
