import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../core/navigation/app_navigation.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../integracoes/integracoes_screen.dart';
import '../compromissos/gestao_compromissos_screen.dart';
import '../rotinas/gestao_rotinas_screen.dart';
import '../medication/gestao_medicamentos_screen.dart';

/// Tela de Configurações
/// Centraliza configurações do app
class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppScaffoldWithWaves(
      appBar: AppBar(
        title: Text(
          'Configurações',
          style: GoogleFonts.leagueSpartan(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
            // Seção: Gestão
            _buildSection(
              context,
              title: 'Gestão',
              children: [
                _buildConfigButton(
                  context,
                  icon: Icons.medication_liquid,
                  text: 'Medicamentos',
                  subtitle: 'Gerenciar medicamentos',
                  onTap: () {
                    Navigator.push(
                      context,
                      AppNavigation.smoothRoute(
                        const GestaoMedicamentosScreen(),
                      ),
                    );
                  },
                ),
                _buildConfigButton(
                  context,
                  icon: Icons.calendar_today,
                  text: 'Compromissos',
                  subtitle: 'Gerenciar compromissos e consultas',
                  onTap: () {
                    Navigator.push(
                      context,
                      AppNavigation.smoothRoute(
                        const GestaoCompromissosScreen(),
                      ),
                    );
                  },
                ),
                _buildConfigButton(
                  context,
                  icon: Icons.schedule_rounded,
                  text: 'Rotinas',
                  subtitle: 'Gerenciar rotinas e atividades',
                  onTap: () {
                    Navigator.push(
                      context,
                      AppNavigation.smoothRoute(
                        const GestaoRotinasScreen(),
                      ),
                    );
                  },
                ),
                _buildConfigButton(
                  context,
                  icon: Icons.camera_alt,
                  text: 'Integrações',
                  subtitle: 'Leitura de receita com OCR',
                  onTap: () {
                    Navigator.push(
                      context,
                      AppNavigation.smoothRoute(
                        const IntegracoesScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Seção: Notificações
            _buildSection(
              context,
              title: 'Notificações',
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active, color: Colors.white),
                  title: Text(
                    'Notificações de Medicamentos',
                    style: GoogleFonts.leagueSpartan(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    'Receber lembretes de horários',
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  value: true, // TODO: Implementar persistência
                  onChanged: (value) {
                    // TODO: Salvar preferência
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.event_available, color: Colors.white),
                  title: Text(
                    'Notificações de Compromissos',
                    style: GoogleFonts.leagueSpartan(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    'Receber lembretes de compromissos',
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  value: true, // TODO: Implementar persistência
                  onChanged: (value) {
                    // TODO: Salvar preferência
                  },
                ),
              ],
            ),

            // Seção: Acessibilidade
            _buildSection(
              context,
              title: 'Acessibilidade',
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up, color: Colors.white),
                  title: Text(
                    'Falar Textos',
                    style: GoogleFonts.leagueSpartan(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    'Text-to-Speech para leitura',
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  value: true, // TODO: Implementar persistência
                  onChanged: (value) {
                    // TODO: Salvar preferência
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: Colors.white),
                  title: Text(
                    'Vibração',
                    style: GoogleFonts.leagueSpartan(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    'Feedback háptico nas ações',
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  value: true, // TODO: Implementar persistência
                  onChanged: (value) {
                    // TODO: Salvar preferência
                  },
                ),
              ],
            ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            title,
            style: GoogleFonts.leagueSpartan(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildConfigButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
      title: Text(
        text,
        style: GoogleFonts.leagueSpartan(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.leagueSpartan(
          fontSize: 14,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.white.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }
}

