import 'package:flutter/material.dart';
import '../../idoso/dashboard_screen.dart';
import '../../medication/gestao_medicamentos_screen.dart';
import '../../idoso/compromissos_screen.dart';
import '../../idoso/ajuda_screen.dart';
import '../../../widgets/nav_item.dart';
import '../../../theme/app_theme.dart';
import '../../../core/navigation/app_navigation.dart';

/// Shell de navegação para o perfil IDOSO
/// BottomBar com 4 itens, fontes gigantes, acessibilidade extrema
class IdosoNavigationShell extends StatefulWidget {
  const IdosoNavigationShell({super.key});

  @override
  State<IdosoNavigationShell> createState() => _IdosoNavigationShellState();
}

class _IdosoNavigationShellState extends State<IdosoNavigationShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    IdosoDashboardScreen(),
    GestaoMedicamentosScreen(),
    CompromissosIdosoScreen(),
    AjudaScreen(),
  ];

  @override
  void initState() {
    super.initState();
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              AppNavigation.smoothRoute(
                const AjudaScreen(),
              ),
            );
          },
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.warning_amber_rounded, size: 28),
          label: const Text(
            'SOS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          elevation: 8,
          tooltip: 'Botão de Emergência SOS',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
        ),
      ),
    );
  }
}
