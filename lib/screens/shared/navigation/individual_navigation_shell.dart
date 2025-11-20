import 'package:flutter/material.dart';
import '../../individual/dashboard_screen.dart';
import '../../medication/gestao_medicamentos_screen.dart';
import '../../individual/rotina_screen.dart';
import '../../shared/perfil_screen.dart';
import '../../../widgets/nav_item.dart';

/// Shell de navegação para o perfil INDIVIDUAL
/// BottomBar com 4 itens, navegação padrão
class IndividualNavigationShell extends StatefulWidget {
  const IndividualNavigationShell({super.key});

  @override
  State<IndividualNavigationShell> createState() => _IndividualNavigationShellState();
}

class _IndividualNavigationShellState extends State<IndividualNavigationShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    IndividualDashboardScreen(),
    GestaoMedicamentosScreen(),
    RotinaScreen(),
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
                icon: Icons.home_rounded,
                label: 'Início',
                isSelected: _selectedIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
              NavItem(
                icon: Icons.medication_liquid,
                label: 'Medicamentos',
                isSelected: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              NavItem(
                icon: Icons.schedule_rounded,
                label: 'Rotina',
                isSelected: _selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
              NavItem(
                icon: Icons.person_rounded,
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
