import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Controlador único para uma animação de fade-in suave.
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Função para exibir o pop-up de ajuda.
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF0400B9)),
            SizedBox(width: 10),
            Text('Qual plano escolher?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Para entender a diferença entre os planos e escolher o melhor para você, acesse nosso site:'),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://caremind.online');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text(
                'caremind.online',
                style: TextStyle(
                  color: Color(0xFF0400B9),
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar', style: TextStyle(color: Color(0xFF0400B9))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFA), // Branco Neve
      // AppBar transparente para posicionar a logo e o ícone de ajuda.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 250, // Aumenta o espaço para a logo maior
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 4.0),
          child: Image.asset(
            'assets/images/caremind_deitado.png', // Logo horizontal
            fit: BoxFit.contain, // Usa contain para mostrar a logo inteira
            height: 60, // Aumenta a altura da logo
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF0400B9), size: 28),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Ajuda',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                // Textos principais
                const Text(
                  'Bem-vindo ao CareMind',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'League Spartan',
                    color: Color(0xFF0400B9),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Que tipo de conta deseja criar?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                ),
                const Spacer(flex: 1),
                
                // Card de Plano Individual
                _buildPlanCard(
                  context: context,
                  icon: Icons.person,
                  title: 'Uso Individual',
                  description: 'Para gerenciar seus próprios medicamentos e rotinas de saúde.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen(tipo: 'individual')),
                    );
                  },
                  isPrimary: true,
                ),
                const SizedBox(height: 24),
                
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
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
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
    // Estilos condicionais baseados no tipo de card (primário ou secundário).
    final Color backgroundColor = isPrimary ? const Color(0xFF0400B9) : Colors.white;
    final Color textColor = isPrimary ? Colors.white : const Color(0xFF0400B9);
    final Color iconColor = isPrimary ? Colors.white : const Color(0xFF0400B9);
    final Color iconBackgroundColor = isPrimary ? Colors.white.withOpacity(0.15) : const Color(0xFF0400B9).withOpacity(0.1);
    final Border? border = isPrimary ? null : Border.all(color: const Color(0xFF0400B9), width: 1.5);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: border,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0400B9).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: iconColor),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'League Spartan',
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}