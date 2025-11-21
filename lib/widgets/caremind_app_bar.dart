import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/navigation/app_navigation.dart';
import '../core/state/familiar_state.dart';
import '../core/injection/injection.dart';
import '../screens/shared/configuracoes_screen.dart';
import '../screens/shared/perfil_screen.dart';

/// AppBar padronizada do CareMind
/// Leading: Configurações (esquerda)
/// Title: Dinâmico (centro) ou Seletor de Idoso (se perfil familiar)
/// Actions: Perfil (direita)
/// Estilo: Fundo transparente, ícones brancos
class CareMindAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool isFamiliar; // Se true, mostra seletor de idoso no título

  const CareMindAppBar({
    super.key,
    this.title,
    this.isFamiliar = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    const iconColor = Colors.white;
    const iconSize = 32.0;
    
    return AppBar(
      title: isFamiliar
          ? _buildIdosoSelector(context)
          : (title != null
              ? Text(
                  title!,
                  style: GoogleFonts.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                )
              : null),
      backgroundColor: Colors.transparent,
      foregroundColor: iconColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: true,
      flexibleSpace: const SizedBox.shrink(),
      toolbarOpacity: 1.0,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
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
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
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
            style: GoogleFonts.leagueSpartan(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 20,
            ),
          );
        }

        if (idosos.length == 1) {
          // Se houver apenas um idoso, mostra apenas o nome
          return Text(
            idosoSelecionado?.nome ?? title ?? 'Familiar',
            style: GoogleFonts.leagueSpartan(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 20,
            ),
          );
        }

        // Se houver múltiplos idosos, mostra dropdown
        return GestureDetector(
          onTap: () => _showIdosoSelectorModal(context, familiarState, idosos, idosoSelecionado),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  idosoSelecionado?.nome ?? 'Selecione um idoso',
                  style: GoogleFonts.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mostra modal para selecionar idoso
  void _showIdosoSelectorModal(
    BuildContext context,
    FamiliarState familiarState,
    List<dynamic> idosos,
    dynamic idosoSelecionado,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA8B8FF), Color(0xFF9B7EFF)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Selecione o idoso',
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              ...idosos.map((idoso) {
                final isSelected = idoso.id == idosoSelecionado?.id;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    idoso.nome ?? 'Idoso',
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 18,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.white)
                      : null,
                  onTap: () {
                    familiarState.selecionarIdoso(idoso);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

