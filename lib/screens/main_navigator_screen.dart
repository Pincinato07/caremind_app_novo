// lib/screens/main_navigator_screen.dart

import 'package:flutter/material.dart';
import 'package:caremind/models/perfil.dart';
import 'package:caremind/screens/individual_dashboard_screen.dart';
import 'package:caremind/screens/gestao_medicamentos_screen.dart';
import 'package:caremind/screens/familiar_dashboard_screen.dart';
import 'package:caremind/screens/metricas_screen.dart';
import 'package:caremind/screens/perfil_screen.dart';
import 'package:caremind/screens/familiares_screen.dart';
import 'package:caremind/screens/alertas_screen.dart';


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
  }

  List<Widget> _buildPagesForProfile(String? tipo) {
    if (tipo == 'individual') {
      return [
        const IndividualDashboardScreen(),
        const GestaoMedicamentosScreen(),
        const MetricasScreen(),
        const PerfilScreen(),
      ];
    } else if (tipo == 'familiar') {
      return [
        const FamiliarDashboardScreen(),
        const FamiliaresScreen(),
        const AlertasScreen(),
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
        BottomNavigationBarItem(icon: Icon(Icons.monitor_heart), label: 'Métricas'),
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
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Se o perfil for 'idoso' ou desconhecido, mostramos uma tela de fallback.
    // A lógica real para a tela do idoso será construída aqui no futuro.
    if (widget.perfil.tipo != 'individual' && widget.perfil.tipo != 'familiar') {
      // TODO: Implementar a tela dedicada e simples para o perfil 'Idoso'
      return Scaffold(
        appBar: AppBar(title: const Text('CareMind')),
        body: const Center(child: Text('Tela do Idoso em construção.')),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _buildNavItemsForProfile(widget.perfil.tipo),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Garante que todos os itens apareçam
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0400B9),
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
