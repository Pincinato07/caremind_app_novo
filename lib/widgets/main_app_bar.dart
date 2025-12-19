import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../core/navigation/app_navigation.dart';
import '../screens/shared/configuracoes_screen.dart';
import '../screens/shared/perfil_screen.dart';

/// AppBar principal com ícones de configurações e perfil
/// Configurações no canto superior esquerdo
/// Perfil no canto superior direito
class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;

  const MainAppBar({
    super.key,
    this.title,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    const iconColor = AppColors.textPrimary;
    const iconSize = 28.0;

    return AppBar(
      title: title != null
          ? Text(
              title!,
              style: AppTextStyles.leagueSpartan(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 20,
              ),
            )
          : null,
      backgroundColor: AppColors.surface,
      foregroundColor: iconColor,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: true,
      flexibleSpace: const SizedBox.shrink(),
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: iconColor,
            size: iconSize,
          ),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          onPressed: () {
            Navigator.push(
              context,
              AppNavigation.smoothRoute(
                const ConfiguracoesScreen(),
              ),
            );
          },
          tooltip: 'Configurações',
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: const Icon(
              Icons.person_outline_rounded,
              color: iconColor,
              size: iconSize,
            ),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            onPressed: () {
              Navigator.push(
                context,
                AppNavigation.smoothRoute(
                  const PerfilScreen(),
                ),
              );
            },
            tooltip: 'Perfil',
          ),
        ),
      ],
    );
  }
}
