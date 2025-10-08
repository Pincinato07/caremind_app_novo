// lib/screens/main_navigator_screen.dart

import 'package:caremind/screens/shared/perfil_screen.dart';
import 'package:flutter/material.dart';
import '../../models/perfil.dart';
import '../individual/dashboard_screen.dart';
import '../individual/rotina_screen.dart';
import '../medication/gestao_medicamentos_screen.dart';
import '../familiar/dashboard_screen.dart';
import '../familia_gerenciamento/familiares_screen.dart';


class MainNavigatorScreen extends StatefulWidget {
  final Perfil perfil;

  const MainNavigatorScreen({super.key, required this.perfil});

  @override
  State<MainNavigatorScreen> createState() => _MainNavigatorScreenState();
}

class _MainNavigatorScreenState extends State<MainNavigatorScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Monta a lista de páginas com base no tipo de perfil
    _pages = _buildPagesForProfile(widget.perfil.tipo);
    print('MainNavigatorScreen - Inicializado com ${_pages.length} páginas para tipo: ${widget.perfil.tipo}');
  }

  List<Widget> _buildPagesForProfile(String? tipo) {
    if (tipo == 'individual') {
      return [
        const IndividualDashboardScreen(),
        const GestaoMedicamentosScreen(),
        const RotinaScreen(),
        const PerfilScreen(),
      ];
    } else if (tipo == 'familiar') {
      return [
        const FamiliarDashboardScreen(),
        const FamiliaresScreen(),
        _buildAlertasScreen(),
        const PerfilScreen(),
      ];
    }
    // Fallback, embora não deva ser alcançado pela lógica de redirecionamento
    return [const Center(child: Text('Tipo de perfil inválido'))];
  }

  List<BottomNavigationBarItem> _buildNavItemsForProfile(String? tipo) {
     if (tipo == 'individual') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Início'),
        BottomNavigationBarItem(icon: Icon(Icons.medication_liquid), label: 'Medicamentos'),
        BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Rotina'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
      ];
    } else if (tipo == 'familiar') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Início'),
        BottomNavigationBarItem(icon: Icon(Icons.groups_rounded), label: 'Familiares'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Alertas'),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: 'Perfil'),
      ];
    }
    return [];
  }

  void _onItemTapped(int index) {
    print('MainNavigatorScreen - Item tapped: $index, Pages length: ${_pages.length}');
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildAlertasScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        backgroundColor: const Color(0xFF0400B9),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Tela de Alertas em desenvolvimento.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug log para verificar o tipo do perfil
    print('MainNavigatorScreen - Tipo do perfil: ${widget.perfil.tipo}');
    print('MainNavigatorScreen - Páginas disponíveis: ${_pages.length}');

    // Se o perfil for null ou 'idoso' ou desconhecido, mostramos uma tela de fallback.
    // A lógica real para a tela do idoso será construída aqui no futuro.
    if (widget.perfil.tipo == null || (widget.perfil.tipo != 'individual' && widget.perfil.tipo != 'familiar')) {
      print('MainNavigatorScreen - Mostrando tela de fallback para tipo: ${widget.perfil.tipo}');
      // TODO: Implementar a tela dedicada e simples para o perfil 'Idoso'
      return Scaffold(
        appBar: AppBar(title: const Text('CareMind')),
        body: const Center(child: Text('Tela do Idoso em construção.')),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex.clamp(0, _pages.length - 1),
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: _buildNavItemsForProfile(widget.perfil.tipo),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0400B9),
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
          ),
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 11,
        ),
      ),
    );
  }
}
