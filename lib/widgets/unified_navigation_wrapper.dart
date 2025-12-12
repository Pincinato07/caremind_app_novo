import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'nav_item.dart';

/// Wrapper unificado de navegação para todos os perfis
/// Resolve o problema dos "3 shells separados" com bottomNav condicional
class UnifiedNavigationWrapper extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final List<NavigationItem> items;
  final Function(int) onItemTapped;
  final String? userType; // 'individual', 'familiar', 'idoso'
  final Color? backgroundColor;

  const UnifiedNavigationWrapper({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.items,
    required this.onItemTapped,
    this.userType,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppColors.background,
        body: body,
        bottomNavigationBar: _buildBottomNav(context),
      ),
    );
  }

  Widget? _buildBottomNav(BuildContext context) {
    // Idoso pode ter navegação simplificada ou nenhuma dependendo do design
    // Por ora, manteremos para todos, mas condicional no futuro
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: 6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              items.length,
              (index) => NavItem(
                icon: items[index].icon,
                label: items[index].label,
                isSelected: currentIndex == index,
                onTap: () => onItemTapped(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item de navegação unificado
class NavigationItem {
  final IconData icon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.label,
  });
}

/// Badge de perfil ativo para indicar qual tipo de conta está usando
class ProfileTypeBadge extends StatelessWidget {
  final String? userType;

  const ProfileTypeBadge({super.key, this.userType});

  @override
  Widget build(BuildContext context) {
    if (userType == null) return const SizedBox.shrink();

    final config = _getBadgeConfig(userType!);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: config.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: 14,
            color: config.color,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: AppTextStyles.bodySmall.copyWith(
              color: config.color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getBadgeConfig(String type) {
    switch (type.toLowerCase()) {
      case 'individual':
        return _BadgeConfig(
          label: 'Individual',
          icon: Icons.person,
          color: AppColors.info,
        );
      case 'familiar':
        return _BadgeConfig(
          label: 'Familiar',
          icon: Icons.groups,
          color: AppColors.accent,
        );
      case 'idoso':
        return _BadgeConfig(
          label: 'Idoso',
          icon: Icons.elderly,
          color: AppColors.success,
        );
      default:
        return _BadgeConfig(
          label: 'Usuário',
          icon: Icons.person_outline,
          color: AppColors.textSecondary,
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color color;

  _BadgeConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
