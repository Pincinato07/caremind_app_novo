import 'package:flutter/material.dart';
import '../../idoso/dashboard_screen.dart';
import '../../medication/gestao_medicamentos_screen.dart';
import '../../idoso/compromissos_screen.dart';
import '../../idoso/ajuda_screen.dart';
import '../../../widgets/nav_item.dart';

/// Shell de navegação para o perfil IDOSO
/// BottomBar com 4 itens, fontes gigantes, acessibilidade extrema
class IdosoNavigationShell extends StatefulWidget {
  const IdosoNavigationShell({super.key});

  @override
  State<IdosoNavigationShell> createState() => _IdosoNavigationShellState();
}

class _IdosoNavigationShellState extends State<IdosoNavigationShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _pageController;

  final List<Widget> _pages = const [
    IdosoDashboardScreen(),
    GestaoMedicamentosScreen(),
    CompromissosIdosoScreen(),
    AjudaScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });
    _pageController.forward(from: 0.0).then((_) {
      _pageController.reverse();
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
                label: 'Remédios',
                isSelected: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              NavItem(
                icon: Icons.calendar_today,
                label: 'Agenda',
                isSelected: _selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
              NavItem(
                icon: Icons.help_outline_rounded,
                label: 'Ajuda',
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

