import 'package:flutter/material.dart';
import '../../familiar/dashboard_screen.dart';
import '../../familia_gerenciamento/familiares_screen.dart';
import '../../shared/alertas_screen.dart';
import '../../shared/gestao_screen.dart';
import '../../../widgets/nav_item.dart';
import '../../../core/state/familiar_state.dart';
import '../../../core/injection/injection.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

/// Shell de navegação para o perfil FAMILIAR/CUIDADOR
/// BottomBar com 4 itens: Início, Família, Notificações, Gestão
/// AppBar removida - cada tela filha terá sua própria AppBar
/// Perfil acessível apenas pela AppBar
class FamiliarNavigationShell extends StatefulWidget {
  const FamiliarNavigationShell({super.key});

  @override
  State<FamiliarNavigationShell> createState() => _FamiliarNavigationShellState();
}

class _FamiliarNavigationShellState extends State<FamiliarNavigationShell> {
  int _selectedIndex = 0;
  bool _isInitialized = false;

  final List<Widget> _pages = const [
    FamiliarDashboardScreen(),
    FamiliaresScreen(),
    AlertasScreen(),
    GestaoScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeFamiliarState();
  }

  Future<void> _initializeFamiliarState() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final familiarState = getIt<FamiliarState>();
      final user = supabaseService.currentUser;

      if (user != null && !_isInitialized) {
        await familiarState.carregarIdosos(user.id);
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // Erro ao inicializar - continuar mesmo assim
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(
              top: BorderSide(color: AppColors.border),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  NavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Início',
                    isSelected: _selectedIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  NavItem(
                    icon: Icons.groups_rounded,
                    label: 'Família',
                    isSelected: _selectedIndex == 1,
                    onTap: () => _onItemTapped(1),
                  ),
                  NavItem(
                    icon: Icons.notifications_rounded,
                    label: 'Notificações',
                    isSelected: _selectedIndex == 2,
                    onTap: () => _onItemTapped(2),
                  ),
                  NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Gestão',
                    isSelected: _selectedIndex == 3,
                    onTap: () => _onItemTapped(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
