import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';
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

  // Register controllers (step 1)
  final _registerFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isRegisterLoading = false;

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

  void _continueRegister() {
    if (!_registerFormKey.currentState!.validate()) return;
    _showSnack('Passo 1 validado. Próximos passos ainda não implementados.');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Global gradient background (135º: topRight -> bottomLeft)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFFA8B8FF), Color(0xFF9B7EFF)],
              ),
            ),
          ),
          // Global animated waves per DS (transparent -> primary @ low alpha)
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              key: const ValueKey('auth_waves_v3'),
              height: (MediaQuery.of(context).size.width >= 1024) ? 360 : 260,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Underlay gradient to boost contrast behind waves
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x1A0400BA), // ~10%
                          Color(0x260400BA), // ~15%
                        ],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  WaveWidget(
                    config: CustomConfig(
                      gradients: [
                        [const Color(0x000400BA), const Color(0x330400BA)], // 0% -> 20%
                        [const Color(0x000400BA), const Color(0x4D0400BA)], // 0% -> 30%
                        [const Color(0x000400BA), const Color(0x660400BA)], // 0% -> 40%
                      ],
                      durations: const [25000, 20000, 15000],
                      heightPercentages: const [0.35, 0.45, 0.55],
                      blur: MaskFilter.blur(BlurStyle.solid, 10),
                      gradientBegin: Alignment.topLeft,
                      gradientEnd: Alignment.bottomRight,
                    ),
                    size: Size(double.infinity, (MediaQuery.of(context).size.width >= 1024) ? 360 : 260),
                    backgroundColor: Colors.transparent,
                    waveAmplitude: 0,
                  ),
                ],
              ),
            ),
          ),
          // Top logo (global)
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Builder(builder: (context) {
                      final w = MediaQuery.of(context).size.width;
                      final h = (w * 0.08).clamp(48.0, 80.0);
                      return Image.asset(
                        'assets/images/caremind_deitado.png',
                        height: h,
                      );
                    }),
                  ),
                ),
                // Animated card switcher (only the card changes)
                Positioned.fill(
                  child: Align(
                    // Lower the card a bit on the screen (y: 0 is center; 0.32 pushes it further down)
                    alignment: const Alignment(0, 0.32),
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
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) {
              return const Color(0xFF020054); // 20% darker approx
            }
            if (states.contains(MaterialState.hovered) || states.contains(MaterialState.focused)) {
              return const Color(0xFF0600E0); // 10% darker/active
            }
            return baseColor;
          }),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.06)),
          elevation: MaterialStateProperty.all(6),
          shadowColor: MaterialStateProperty.all(baseColor.withOpacity(0.2)),
          padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        child: Text(label),
      ),
    );
  }

  // Card builders (glassmorphism per spec)
  Widget _glassContainer({required Widget child, Key? key}) {
    return KeyedSubtree(
      key: key,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = MediaQuery.of(context).size.width;
          final pad = screenW.clamp(320, 1600) / 1000 * 20; // aproximação do clamp(16..28)
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: screenW * 0.85,
                    constraints: const BoxConstraints(maxWidth: 380),
                    padding: EdgeInsets.all(pad.clamp(16, 28)),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(31, 38, 135, 0.3),
                          blurRadius: 24,
                          offset: Offset(0, 6),
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
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.06),
                            Colors.transparent,
                          ],
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
      style: GoogleFonts.leagueSpartan(fontSize: size, fontWeight: FontWeight.w700, height: 1.2, color: Colors.white,
          shadows: [Shadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 2), blurRadius: 4)]),
    );
  }

  // Helper: input with glow on focus
  Widget _glowField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
  }) {
    return Focus(
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            boxShadow: focused
                ? [
                    BoxShadow(color: Colors.white.withOpacity(0.20), blurRadius: 12, spreadRadius: 0, offset: const Offset(0, 0)),
                    BoxShadow(color: Colors.white.withOpacity(0.10), blurRadius: 6, spreadRadius: 0, offset: const Offset(0, 0)),
                  ]
                : const [],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            validator: validator,
            style: const TextStyle(color: Color(0xFF2D3748)),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 2),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        );
      }),
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
                  color: const Color(0xFF0400BA),
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xFF0400BA),
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
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Não tem conta ainda? ', style: TextStyle(color: Colors.white, fontSize: 14)),
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
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                ),
                child: const Text('Voltar ao Início', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterCard({Key? key}) {
    return _glassContainer(
      key: key,
      child: Form(
        key: _registerFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _responsiveTitle('Registrar'),
            const SizedBox(height: 6),
            Text('Passo 1 de 3', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.9))),
            const SizedBox(height: 24),
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
              validator: (v) => v == null || v.isEmpty ? 'Informe o e-mail' : null,
            ),
            const SizedBox(height: 20),
            _isRegisterLoading
                ? const SizedBox(height: 48, child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0400BA)))))
                : _primaryButton(label: 'Continuar', onPressed: _continueRegister),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Já tem uma conta? ', style: TextStyle(color: Colors.white, fontSize: 14)),
                  GestureDetector(
                    onTap: () => setState(() => _mode = AuthMode.login),
                    child: const Text('Fazer login', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.black12),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF171717),
                  side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                ),
                child: const Text('Voltar ao Início', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
