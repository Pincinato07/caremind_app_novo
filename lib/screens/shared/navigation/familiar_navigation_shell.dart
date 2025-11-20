import 'package:flutter/material.dart';
import '../../familiar/dashboard_screen.dart';
import '../../familia_gerenciamento/familiares_screen.dart';
import '../../shared/alertas_screen.dart';
import '../../shared/perfil_screen.dart';
import '../../../widgets/nav_item.dart';

/// Shell de navegação para o perfil FAMILIAR/CUIDADOR
/// BottomBar com 4 itens, dashboard de gestão
class FamiliarNavigationShell extends StatefulWidget {
  const FamiliarNavigationShell({super.key});

  @override
  State<FamiliarNavigationShell> createState() => _FamiliarNavigationShellState();
}

class _FamiliarNavigationShellState extends State<FamiliarNavigationShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    FamiliarDashboardScreen(),
    FamiliaresScreen(),
    AlertasScreen(),
    PerfilScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: IndexedStack(
          key: ValueKey(_selectedIndex),
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.98),
              Colors.white,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
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
                label: 'Idosos',
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
                icon: Icons.account_circle_rounded,
                label: 'Perfil',
                isSelected: _selectedIndex == 3,
                onTap: () => _onItemTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

