import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/navigation/app_navigation.dart';
import '../screens/shared/configuracoes_screen.dart';
import '../screens/shared/perfil_screen.dart';
import '../screens/shared/relatorios_screen.dart';
import '../screens/integracoes/integracoes_screen.dart';
import '../services/supabase_service.dart';
import '../core/injection/injection.dart';
import '../services/subscription_service.dart';

/// Menu secundário (hamburger) para acesso a funcionalidades adicionais
/// Inclui: Relatórios, Integrações, Configurações, Perfil, Sair
class SecondaryMenu extends StatelessWidget {
  final bool isFamiliar;
  final bool isIdoso;

  const SecondaryMenu({
    super.key,
    this.isFamiliar = false,
    this.isIdoso = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.menu_rounded,
        color: AppColors.textPrimary,
        size: 28.0,
      ),
      tooltip: 'Menu',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      offset: const Offset(0, 56),
      itemBuilder: (context) => [
        // Relatórios (apenas se não for idoso)
        if (!isIdoso)
          PopupMenuItem<String>(
            value: 'relatorios',
            enabled: _canAccessReports(),
            child: Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  color: _canAccessReports()
                      ? AppColors.primary
                      : AppColors.textHint,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Relatórios',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _canAccessReports()
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                      if (!_canAccessReports())
                        Text(
                          'Premium',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Integrações
        PopupMenuItem<String>(
          value: 'integracoes',
          child: Row(
            children: [
              const Icon(
                Icons.power_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Integrações',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // Configurações
        PopupMenuItem<String>(
          value: 'configuracoes',
          child: Row(
            children: [
              const Icon(
                Icons.settings_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Configurações',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // Perfil
        PopupMenuItem<String>(
          value: 'perfil',
          child: Row(
            children: [
              const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Perfil',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // Sair
        PopupMenuItem<String>(
          value: 'sair',
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Sair',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) => _handleMenuSelection(context, value),
    );
  }

  bool _canAccessReports() {
    try {
      final subscriptionService = getIt<SubscriptionService>();
      return subscriptionService.canUseReports;
    } catch (e) {
      return false;
    }
  }

  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'relatorios':
        Navigator.push(
          context,
          AppNavigation.smoothRoute(
            const RelatoriosScreen(),
          ),
        );
        break;

      case 'integracoes':
        Navigator.push(
          context,
          AppNavigation.smoothRoute(
            const IntegracoesScreen(),
          ),
        );
        break;

      case 'configuracoes':
        Navigator.push(
          context,
          AppNavigation.smoothRoute(
            const ConfiguracoesScreen(),
          ),
        );
        break;

      case 'perfil':
        Navigator.push(
          context,
          AppNavigation.smoothRoute(
            const PerfilScreen(),
          ),
        );
        break;

      case 'sair':
        _showLogoutConfirmation(context);
        break;
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Sair da Conta',
          style: AppTextStyles.leagueSpartan(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Tem certeza que deseja sair?',
          style: AppTextStyles.leagueSpartan(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: AppTextStyles.leagueSpartan(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _logout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Sair',
              style: AppTextStyles.leagueSpartan(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final supabaseService = getIt<SupabaseService>();
      await supabaseService.signOut();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sair: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
