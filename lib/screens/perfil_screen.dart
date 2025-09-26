// lib/screens/perfil_screen.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 80,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tela de Perfil',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Gerencie seus dados pessoais, foto de perfil e configurações',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
    
    return InkWell(
      onTap: onTap,
      borderRadius: AppBorderRadius.mediumAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isLogout ? colors.error.withOpacity(0.1) : colors.surface,
          borderRadius: AppBorderRadius.mediumAll,
          border: Border.all(
            color: isLogout 
                ? colors.error.withOpacity(0.2) 
                : colors.outline.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isLogout ? colors.error : colors.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isLogout ? colors.error : colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isLogout ? colors.error : colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
