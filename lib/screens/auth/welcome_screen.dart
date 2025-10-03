import 'package:flutter/material.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _animationCompleted = false;
  bool _isHoveringIndividual = false;
  bool _isHoveringFamily = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutQuart,
    ));


    _animationController.forward().then((_) {
      setState(() {
        _animationCompleted = true;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajuda'),
        content: const Text('Para obter ajuda, visite nosso site: caremind.online'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.help_outline, color: colors.primary, size: 28),
          onPressed: () => _showHelpDialog(context),
          tooltip: 'Ajuda',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/images/caremind_deitado.png',
              height: 40,
              color: colors.primary,
            ),
          ),
        ],
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho com animação
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: _animationCompleted ? _buildHeader(theme, colors) : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 32),
                  // Texto de boas-vindas
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Bem-vindo ao CareMind',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Escolha o tipo de conta que melhor atende às suas necessidades',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Cards de plano com animação de deslize
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Card de Plano Individual
                        _buildPlanCard(
                          context: context,
                          icon: Icons.person,
                          title: 'Uso Individual',
                          description: 'Para gerenciar seus próprios medicamentos e rotinas de saúde.',
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(tipo: 'individual'),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOutQuart;
                                                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                  var offsetAnimation = animation.drive(tween);
                                  return SlideTransition(position: offsetAnimation, child: child);
                                },
                              ),
                            );
                          },
                          isPrimary: true,
                        ),
                        const SizedBox(height: 20),
                        // Card de Plano Família
                        _buildPlanCard(
                          context: context,
                          icon: Icons.family_restroom,
                          title: 'Plano Família',
                          description: 'Para cuidar de um familiar e acompanhar os tratamentos de perto.',
                          onTap: () {
                            Navigator.pushNamed(context, '/family-role-selection');
                          },
                          isPrimary: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Cabeçalho com animação
  Widget _buildHeader(ThemeData theme, ColorScheme colors) {
    return const SizedBox(height: 80);
  }


  // --- WIDGET REUTILIZÁVEL PARA OS CARDS DE PLANO ---
  Widget _buildPlanCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 375;
    final bool isHovering = isPrimary ? _isHoveringIndividual : _isHoveringFamily;

    // Cores e estilos condicionais
    final Color backgroundColor = isPrimary ? colors.primary : colors.surface;
    final Color textColor = isPrimary ? colors.onPrimary : colors.primary;
    final Color iconColor = isPrimary ? colors.onPrimary : colors.primary;
    final Color iconBackgroundColor = isPrimary
        ? colors.onPrimary.withOpacity(0.15)
        : colors.primary.withOpacity(0.1);

    return MouseRegion(
      onEnter: (_) => setState(() {
        if (isPrimary) {
          _isHoveringIndividual = true;
        } else {
          _isHoveringFamily = true;
        }
      }),
      onExit: (_) => setState(() {
        if (isPrimary) {
          _isHoveringIndividual = false;
        } else {
          _isHoveringFamily = false;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
        transform: isHovering ? (Matrix4.identity()..translate(0, -4, 0)) : Matrix4.identity(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: isPrimary
                ? null
                : Border.all(color: colors.primary.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(isPrimary ? 0.3 : 0.1),
                blurRadius: isHovering ? 30 : 20,
                offset: Offset(0, isHovering ? 12 : 8),
                spreadRadius: isHovering ? 2 : 1,
              ),
            ],
            gradient: isPrimary && isHovering
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary,
                      colors.primary.withBlue((colors.primary.blue * 1.2).toInt().clamp(0, 255)),
                    ],
                  )
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: isPrimary ? colors.onPrimary.withOpacity(0.1) : colors.primary.withOpacity(0.1),
              highlightColor: isPrimary ? colors.onPrimary.withOpacity(0.15) : colors.primary.withOpacity(0.15),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Ícone com fundo e efeito de flutuação
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: iconBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (isPrimary || isHovering)
                            BoxShadow(
                              color: (isPrimary ? colors.onPrimary : colors.primary).withOpacity(0.2),
                              blurRadius: isHovering ? 15 : 10,
                              spreadRadius: isHovering ? 1 : 0,
                              offset: Offset(0, isHovering ? 6 : 4),
                            ),
                        ],
                        gradient: isHovering && !isPrimary
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colors.surface,
                                  colors.surface.withOpacity(0.7),
                                ],
                              )
                            : null,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Icon(
                          icon,
                          key: ValueKey<bool>(isHovering),
                          size: isSmallScreen ? 26 : 32,
                          color: isHovering && !isPrimary ? colors.primary : iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Conteúdo do card
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 18 : 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Descrição
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: textColor.withOpacity(0.9),
                              height: 1.4,
                              fontSize: isSmallScreen ? 13 : 14,
                            ),
                          ),
                          if (isPrimary) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.onPrimary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Recomendado',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}