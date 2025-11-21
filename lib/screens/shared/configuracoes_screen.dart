import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';

/// Tela de Configurações
/// Centraliza configurações do app
class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: const CareMindAppBar(title: 'Configurações'),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
            // Seção: Notificações
            _buildSection(
              context,
              title: 'Notificações',
              children: [
                _buildSwitchTile(
                  context,
                  icon: Icons.notifications_active,
                  title: 'Notificações de Medicamentos',
                  subtitle: 'Receber lembretes de horários',
                  value: true,
                  onChanged: (value) {
                    // TODO: Salvar preferência
                  },
                ),
                _buildSwitchTile(
                  context,
                  icon: Icons.event_available,
                  title: 'Notificações de Compromissos',
                  subtitle: 'Receber lembretes de compromissos',
                  value: true,
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
                _buildSwitchTile(
                  context,
                  icon: Icons.volume_up,
                  title: 'Falar Textos',
                  subtitle: 'Text-to-Speech para leitura',
                  value: true,
                  onChanged: (value) {
                    // TODO: Salvar preferência
                  },
                ),
                _buildSwitchTile(
                  context,
                  icon: Icons.vibration,
                  title: 'Vibração',
                  subtitle: 'Feedback háptico nas ações',
                  value: true,
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

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        secondary: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: GoogleFonts.leagueSpartan(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.leagueSpartan(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF0400BA),
      ),
    );
  }
}

