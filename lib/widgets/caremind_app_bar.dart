import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../core/navigation/app_navigation.dart';
import '../core/state/familiar_state.dart';
import '../core/injection/injection.dart';
import '../screens/shared/configuracoes_screen.dart';
import '../screens/shared/perfil_screen.dart';
import 'profile_switch_dialog.dart';

/// AppBar padronizada do CareMind
/// Leading: Back button (se pode voltar) ou Configurações (esquerda)
/// Title: Dinâmico (centro) ou Seletor de Idoso (se perfil familiar)
/// Actions: Perfil (direita)
/// Estilo: Fundo transparente, ícones brancos
class CareMindAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool isFamiliar; // Se true, mostra seletor de idoso no título
  final bool showBackButton; // Se true, força mostrar back button mesmo se não puder voltar
  final Widget? leading; // Widget customizado para o leading
  final bool showSearchButton;
  final bool showVoiceButton;
  final VoidCallback? onSearchTap;
  final VoidCallback? onVoiceTap;

  const CareMindAppBar({
    super.key,
    this.title,
    this.isFamiliar = false,
    this.showBackButton = false,
    this.leading,
    this.showSearchButton = false,
    this.showVoiceButton = false,
    this.onSearchTap,
    this.onVoiceTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  /// Constrói o leading (botão esquerdo)
  /// Mostra back button apenas se showBackButton=true
  /// Caso contrário, mostra botão de configurações
  Widget _buildLeading(BuildContext context) {
    // Se foi fornecido um leading customizado, usa ele
    if (leading != null) {
      return leading!;
    }
    
    // Mostrar botão de voltar APENAS se explicitamente solicitado
    if (showBackButton) {
      return Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Semantics(
          label: 'Voltar',
          hint: 'Toque para voltar',
          button: true,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 28.0,
            ),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            onPressed: () {
              // Apenas fazer pop, nunca logout
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            tooltip: 'Voltar',
          ),
        ),
      );
    }

    // Se não deve mostrar back button, mostra botão de configurações
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Semantics(
        label: 'Configurações',
        hint: 'Toque para abrir configurações',
        button: true,
        child: IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: AppColors.textPrimary,
            size: 28.0,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    const iconColor = AppColors.textPrimary;
    const iconSize = 28.0;
    
    return AppBar(
      title: isFamiliar
          ? _buildIdosoSelector(context)
          : (title != null
              ? Text(
                  title!,
                  style: AppTextStyles.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 20,
                  ),
                )
              : null),
      backgroundColor: AppColors.surface,
      foregroundColor: iconColor,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.04),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarOpacity: 1.0,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
      leading: _buildLeading(context),
      actions: [
        if (showSearchButton)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.search_rounded, color: iconColor, size: iconSize),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: onSearchTap,
              tooltip: 'Buscar',
            ),
          ),
        if (showVoiceButton)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.mic_none_rounded, color: iconColor, size: iconSize),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: onVoiceTap,
              tooltip: 'Falar',
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Semantics(
            label: 'Perfil',
            hint: 'Toque para abrir perfil',
            button: true,
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
        ),
      ],
    );
  }

  /// Constrói o seletor de idoso para perfil familiar
  Widget _buildIdosoSelector(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    
    return ListenableBuilder(
      listenable: familiarState,
      builder: (context, _) {
        final idosoSelecionado = familiarState.idosoSelecionado;
        final idosos = familiarState.idososVinculados;

        if (idosos.isEmpty) {
          return Text(
            title ?? 'Familiar',
            style: AppTextStyles.leagueSpartan(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 20,
            ),
          );
        }

        if (idosos.length == 1) {
          return Text(
            idosoSelecionado?.nome ?? title ?? 'Familiar',
            style: AppTextStyles.leagueSpartan(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 20,
            ),
          );
        }

        // Se houver múltiplos idosos, mostra dropdown com ProfileSwitchDialog
        return GestureDetector(
          onTap: () => _showProfileSwitchDialog(context, familiarState, idosos, idosoSelecionado),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  idosoSelecionado?.nome ?? 'Selecione um idoso',
                  style: AppTextStyles.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mostra ProfileSwitchDialog para selecionar idoso
  void _showProfileSwitchDialog(
    BuildContext context,
    FamiliarState familiarState,
    List<dynamic> idosos,
    dynamic idosoSelecionado,
  ) {
    showDialog(
      context: context,
      builder: (context) => ProfileSwitchDialog(
        profiles: idosos.map((idoso) => {
          'id': idoso.id,
          'name': idoso.nome ?? 'Idoso',
          'email': idoso.email,
        }).toList(),
        currentProfileId: idosoSelecionado?.id,
        onProfileSelected: (profileId) {
          final idoso = idosos.firstWhere((i) => i.id == profileId);
          familiarState.selecionarIdoso(idoso);
        },
      ),
    );
  }
}