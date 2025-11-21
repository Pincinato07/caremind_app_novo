import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'auth_shell.dart';
import '../../widgets/wave_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'image': 'welcome.svg',
      'title': 'Boas-vindas ao CareMind',
      'subtitle': 'Seu assistente individual para uma rotina de saúde organizada, tranquila e conectada.',
    },
    {
      'image': 'medicamentos.svg',
      'title': 'Lembretes e Rotinas',
      'subtitle': 'Nunca mais esqueça um medicamento ou compromisso. Cadastre suas rotinas e nós organizamos sua agenda.',
    },
    {
      'image': 'cuidador.svg',
      'title': 'Para você ou sua família',
      'subtitle': 'Use no modo Individual para sua própria saúde, ou no modo Familiar para acompanhar seus entes queridos.',
    },
    {
      'image': 'integracoes.svg',
      'title': 'Conectado à sua casa',
      'subtitle': 'Integre com a Alexa para lembretes de voz e confirmação de tarefas sem tocar no celular.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 1.0,
      initialPage: 0,
    );
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    setState(() {
      _currentPage = _pageController.page?.round() ?? 0;
    });
  }

  void _navigateToAuth() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Fade suave combinado com scale
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
            ),
          );
          
          // Scale sutil para dar profundidade
          final scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
            ),
          );
          
          // Slide horizontal muito suave (opcional, pode remover se preferir apenas fade+scale)
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.02, 0.0), // Muito sutil, quase imperceptível
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
            ),
          );
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 400),
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
          final screenH = MediaQuery.of(context).size.height;
          final pad = (screenW * 0.025).clamp(16.0, 28.0);
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Neutral underlay so the BackdropFilter doesn't pick strong hues from the page gradient
                // This keeps the gradient behind the card without tinting the glass excessively
                Positioned.fill(
                  child: Container(color: Colors.white.withValues(alpha: 0.08)),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    width: screenW * 0.85,
                    constraints: BoxConstraints(
                      maxWidth: 380,
                      maxHeight: screenH * 0.75, // More restrictive height constraint
                    ),
                    padding: EdgeInsets.all(pad),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
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
                          Colors.white.withValues(alpha: 0.25),
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.2, 0.6],
                      ),
                    ),
                    child: child, // Remove the inner SingleChildScrollView and ConstrainedBox
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
                          Colors.white.withValues(alpha: 0.5),
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

  // Primary solid button per spec (shadow + 48px height)
  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    final baseColor = const Color(0xFF0400BA);
    return SizedBox(
      height: 44, // Slightly smaller to save space
      width: double.infinity,
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
          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.06)),
          elevation: WidgetStateProperty.all(6),
          shadowColor: WidgetStateProperty.all(baseColor.withValues(alpha: 0.2)),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20, vertical: 10)), // Reduced padding
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5)), // Smaller font
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildOnboardingContent({
    required String svgAsset,
    required String title,
    required String subtitle,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image
          Container(
            height: 140, // Reduced height to prevent overflow
            margin: const EdgeInsets.only(bottom: 20),
            child: SvgPicture.asset(
              'assets/images/$svgAsset',
              fit: BoxFit.contain,
            ),
          ),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.leagueSpartan(
              color: Colors.white,
              fontSize: 20, // Slightly smaller font
              fontWeight: FontWeight.w700,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.leagueSpartan(
              color: Colors.white.withAlpha(230),
              fontSize: 14, // Slightly smaller font
              fontWeight: FontWeight.w400,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLastPage = _currentPage == _pages.length - 1;

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
              key: ValueKey('onboarding_waves_v3'),
              child: OnboardingWaveBackground(),
            ),
          ),
          // Top logo (global)
          SafeArea(
            child: Stack(
              children: [
                // Logo aligned with main card on the left
                Positioned(
                  top: 40, // Same top margin as card alignment
                  left: -19, // Aligned with card's left edge
                  child: Builder(builder: (context) {
                    final w = MediaQuery.of(context).size.width;
                    final double height = (w * 0.12).clamp(35.0, 70.0);
                    return Image.asset(
                      'assets/images/caremind_deitado.png',
                      height: height,
                      fit: BoxFit.contain,
                    );
                  }),
                ),
                // Skip button aligned with main card on the right
                Positioned(
                  top: 40, // Same top margin as card alignment
                  right: 20,
                  child: TextButton(
                    onPressed: _navigateToAuth,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      textStyle: GoogleFonts.leagueSpartan(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Pular'),
                  ),
                ),
                // Animated card switcher (only the card changes)
                Positioned.fill(
                  child: Align(
                    // Raise the card closer to center
                    alignment: const Alignment(0, 0.1), // Moved slightly higher
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _glassContainer(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Page content
                            SizedBox(
                              height: screenHeight * 0.5, // Taller height to display all text
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: _pages.length,
                                physics: const BouncingScrollPhysics(),
                                itemBuilder: (context, index) {
                                  return _buildOnboardingContent(
                                    svgAsset: _pages[index]['image']!,
                                    title: _pages[index]['title']!,
                                    subtitle: _pages[index]['subtitle']!,
                                  );
                                },
                              ),
                            ),

                            // Page indicator
                            SmoothPageIndicator(
                              controller: _pageController,
                              count: _pages.length,
                              effect: WormEffect(
                                dotColor: Colors.white.withAlpha(77),
                                activeDotColor: Colors.white,
                                dotHeight: 6, // Smaller dots
                                dotWidth: 6, // Smaller dots
                                spacing: 6, // Less spacing
                              ),
                              onDotClicked: (index) {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),

                            const SizedBox(height: 16), // Adjusted spacing

                            // Next/Get Started button
                            _primaryButton(
                              label: isLastPage ? 'Começar' : 'Próximo',
                              onPressed: () {
                                if (isLastPage) {
                                  _navigateToAuth();
                                } else {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),

                            const SizedBox(height: 8), // Adjusted spacing
                          ],
                        ),
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
}
