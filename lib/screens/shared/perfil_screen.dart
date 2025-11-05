// lib/screens/perfil_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header com gradiente
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.primary, colors.primaryContainer],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 60,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Meu Perfil',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gerencie suas informações',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimary.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Cards de opções
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                children: [
                  _buildProfileButton(
                    context,
                    icon: Icons.edit,
                    text: 'Editar Perfil',
                    onTap: () {
                      // Navegar para tela de edição de perfil
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.settings,
                    text: 'Configurações',
                    onTap: () {
                      // Navegar para tela de configurações
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.help_outline,
                    text: 'Ajuda e Suporte',
                    onTap: () {
                      // Navegar para tela de ajuda
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.logout,
                    text: 'Sair',
                    isLogout: true,
                    onTap: () {
                      // Implementar lógica de logout
                    },
                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    bool isLogout = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: isLogout
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  colors.primary.withOpacity(0.02),
                ],
              ),
        color: isLogout ? colors.error.withOpacity(0.08) : null,
        borderRadius: AppBorderRadius.largeAll,
        border: Border.all(
          color: isLogout
              ? colors.error.withOpacity(0.3)
              : colors.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isLogout ? colors.error : colors.primary).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppBorderRadius.largeAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLogout
                        ? colors.error.withOpacity(0.1)
                        : colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isLogout ? colors.error : colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isLogout ? colors.error : colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: isLogout ? colors.error : colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
