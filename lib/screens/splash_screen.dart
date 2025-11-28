import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold_with_waves.dart';
import '../services/supabase_service.dart';
import '../core/injection/injection.dart';
import 'shared/main_navigator_screen.dart';
import 'auth/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  String _loadingStatus = 'Inicializando...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Configurar animações
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _updateProgress(String status, double progress) async {
    if (mounted) {
      setState(() {
        _loadingStatus = status;
        _progress = progress;
      });
      // Pequeno delay para suavizar transições
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Progresso: 10% - Inicializando serviços
      await _updateProgress('Carregando serviços...', 0.1);
      
      // Nota: configureDependencies já foi chamado no main.dart
      // Aqui apenas verificamos se está tudo certo
      await Future.delayed(const Duration(milliseconds: 300));

      // Progresso: 30% - Verificando autenticação
      await _updateProgress('Verificando autenticação...', 0.3);
      
      final supabaseService = getIt<SupabaseService>();
      
      // O Supabase Flutter restaura automaticamente a sessão ao inicializar
      // Aguardar um pouco para garantir que a sessão seja restaurada
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Verificar se há uma sessão ativa e um usuário logado
      // O Supabase mantém a sessão automaticamente usando armazenamento seguro
      final user = supabaseService.currentUser;
      
      await Future.delayed(const Duration(milliseconds: 300));

      if (user == null) {
        // Progresso: 70% - Usuário não autenticado
        await _updateProgress('Preparando tela de login...', 0.7);
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Progresso: 100% - Redirecionar para onboarding
        await _updateProgress('Finalizando...', 1.0);
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Fade out da splash enquanto fade in do onboarding
                final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
                  ),
                );
                
                // Scale suave para o onboarding
                final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
                  ),
                );
                
                return FadeTransition(
                  opacity: fadeAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 800),
              reverseTransitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
        return;
      }

      // Progresso: 50% - Carregando perfil
      await _updateProgress('Carregando perfil...', 0.5);
      
      try {
        final perfil = await supabaseService.getProfile(user.id);
        await Future.delayed(const Duration(milliseconds: 400));

        if (perfil == null) {
          // Progresso: 70% - Perfil não encontrado, redirecionar para cadastro
          await _updateProgress('Perfil não encontrado...', 0.7);
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Progresso: 100%
          await _updateProgress('Finalizando...', 1.0);
          await Future.delayed(const Duration(milliseconds: 300));

          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  // Fade out da splash enquanto fade in do onboarding
                  final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
                    ),
                  );
                  
                  // Scale suave para o onboarding
                  final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
                    ),
                  );
                  
                  return FadeTransition(
                    opacity: fadeAnimation,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 800),
                reverseTransitionDuration: const Duration(milliseconds: 400),
              ),
            );
          }
          return;
        }

        // Progresso: 70% - Carregando dados do usuário
        await _updateProgress('Carregando dados...', 0.7);
        await Future.delayed(const Duration(milliseconds: 300));

        // Progresso: 90% - Preparando interface
        await _updateProgress('Preparando interface...', 0.9);
        await Future.delayed(const Duration(milliseconds: 200));

        // Progresso: 100% - Finalizando
        await _updateProgress('Finalizando...', 1.0);
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          // Navegar para a tela principal baseada no perfil
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MainNavigatorScreen(perfil: perfil),
            ),
          );
        }
      } catch (profileError) {
        debugPrint('❌ Erro ao carregar perfil: $profileError');
        // Em caso de erro no perfil, tentar redirecionar para onboarding
        if (mounted) {
          await _updateProgress('Erro ao carregar perfil. Redirecionando...', 0.8);
          await Future.delayed(const Duration(milliseconds: 500));
          
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
                  ),
                );
                
                final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
                  ),
                );
                
                return FadeTransition(
                  opacity: fadeAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 800),
              reverseTransitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('❌ Erro na inicialização: $e');
      
      // Em caso de erro, redirecionar para login
      if (mounted) {
        await _updateProgress('Erro ao carregar. Redirecionando...', 0.8);
        await Future.delayed(const Duration(milliseconds: 500));
        
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenHeight < 700;
    
    return AppScaffoldWithWaves(
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo animado
                        Image.asset(
                          'assets/images/caremind.png',
                          width: screenSize.width * (isSmallScreen ? 0.3 : 0.4),
                          height: screenSize.width * (isSmallScreen ? 0.3 : 0.4),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback se a imagem não existir
                            return Icon(
                              Icons.favorite_rounded,
                              size: screenSize.width * (isSmallScreen ? 0.25 : 0.3),
                              color: Colors.white,
                            );
                          },
                        ),
                        
                        SizedBox(height: isSmallScreen ? 24 : 32),
                        
                        // Nome do app
                        Text(
                          'CareMind',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: isSmallScreen ? 36 : 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2,
                          ).copyWith(
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                offset: const Offset(0, 2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: isSmallScreen ? 4 : 8),
                        
                        // Slogan
                        Text(
                          'Cuidando de quem você ama',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                        
                        SizedBox(height: isSmallScreen ? 32 : 48),
                        
                        // Barra de progresso
                        Container(
                          width: screenSize.width * 0.7,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 500),
                              tween: Tween(begin: 0.0, end: _progress),
                              builder: (context, value, child) {
                                return LinearProgressIndicator(
                                  value: value,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withValues(alpha: 0.9),
                                  ),
                                  minHeight: 6,
                                );
                              },
                            ),
                          ),
                        ),
                        
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        
                        // Status de carregamento
                        Text(
                          _loadingStatus,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        SizedBox(height: isSmallScreen ? 20 : 24),
                        
                        // Indicador de carregamento
                        SizedBox(
                          width: isSmallScreen ? 28 : 32,
                          height: isSmallScreen ? 28 : 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
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
    );
  }

}
