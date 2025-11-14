// lib/screens/main_navigator_screen.dart

import 'package:caremind/screens/shared/perfil_screen.dart';
import 'package:flutter/material.dart';
import '../../models/perfil.dart';
import '../individual/dashboard_screen.dart';
import '../individual/rotina_screen.dart';
import '../idoso/dashboard_screen.dart';
import '../idoso/rotina_screen.dart';
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
    print('🚀 [MainNavigatorScreen] initState - Iniciando com perfil: ${widget.perfil.toMap()}');
    // Monta a lista de páginas com base no tipo de perfil
    _pages = _buildPagesForProfile(widget.perfil.tipo);
    print('📱 [MainNavigatorScreen] initState - ${_pages.length} páginas carregadas para o tipo: ${widget.perfil.tipo}');
  }

  List<Widget> _buildPagesForProfile(String? tipo) {
    print('🔄 [MainNavigatorScreen] _buildPagesForProfile - Tipo de perfil recebido: $tipo');
    
    // Convert to lowercase for case-insensitive comparison
    final tipoLower = tipo?.toLowerCase();
    
    if (tipoLower == 'individual') {
      print('👤 [MainNavigatorScreen] Carregando páginas para perfil INDIVIDUAL');
      return [
        const IndividualDashboardScreen(),
        const GestaoMedicamentosScreen(),
        const RotinaScreen(),
        const PerfilScreen(),
      ];
    } else if (tipoLower == 'idoso') {
      print('👴 [MainNavigatorScreen] Carregando páginas para perfil IDOSO');
      return [
        const IdosoDashboardScreen(),
        const GestaoMedicamentosScreen(),
        const RotinaIdosoScreen(),
        const PerfilScreen(),
      ];
    } else if (tipoLower == 'familiar') {
      print('👨‍👩‍👧‍👦 [MainNavigatorScreen] Carregando páginas para perfil FAMILIAR');
      return [
        const FamiliarDashboardScreen(),
        const FamiliaresScreen(),
        _buildAlertasScreen(),
        const PerfilScreen(),
      ];
    }
    
    print('⚠️ [MainNavigatorScreen] ATENÇÃO: Tipo de perfil não reconhecido: $tipo');
    return [const Center(child: Text('Tipo de perfil inválido'))];
  }

  List<BottomNavigationBarItem> _buildNavItemsForProfile(String? tipo) {
    print('🔘 [MainNavigatorScreen] _buildNavItemsForProfile - Construindo itens de navegação para: $tipo');
    
    // Convert to lowercase for case-insensitive comparison
    final tipoLower = tipo?.toLowerCase();
    
    if (tipoLower == 'individual') {
      print('🔘 [MainNavigatorScreen] Itens para perfil INDIVIDUAL');
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Início'),
        BottomNavigationBarItem(icon: Icon(Icons.medication_liquid), label: 'Medicamentos'),
        BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Rotina'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
      ];
    } else if (tipoLower == 'familiar') {
      print('🔘 [MainNavigatorScreen] Itens para perfil FAMILIAR');
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Início'),
        BottomNavigationBarItem(icon: Icon(Icons.groups_rounded), label: 'Familiares'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Alertas'),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: 'Perfil'),
      ];
    } else if (tipoLower == 'idoso') {
      print('🔘 [MainNavigatorScreen] Itens para perfil IDOSO (usando itens padrão)');
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Início'),
        BottomNavigationBarItem(icon: Icon(Icons.medication_liquid), label: 'Medicamentos'),
        BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Rotina'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
      ];
    }
    
    print('⚠️ [MainNavigatorScreen] Nenhum item de navegação encontrado para o tipo: $tipo');
    return [];
  }

  void _onItemTapped(int index) {
    print('👉 [MainNavigatorScreen] _onItemTapped - Índice: $index, Total de páginas: ${_pages.length}');
    
    if (index < 0 || index >= _pages.length) {
      print('❌ [MainNavigatorScreen] ERRO: Índice $index fora dos limites (0-${_pages.length - 1})');
      return;
    }
    
    final pageName = _getPageName(_pages[index]);
    print('🔄 [MainNavigatorScreen] Navegando para: $pageName');
    
    setState(() {
      _selectedIndex = index;
      print('✅ [MainNavigatorScreen] Índice atualizado para: $_selectedIndex');
    });
  }
  
  String _getPageName(Widget page) {
    return page.runtimeType.toString();
  }

  Widget _buildAlertasScreen() {
    print('🔔 [MainNavigatorScreen] _buildAlertasScreen - Construindo tela de alertas');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        backgroundColor: const Color(0xFF0400B9),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_active, size: 50, color: Colors.blueGrey),
            const SizedBox(height: 16),
            const Text(
              'Tela de Alertas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Em desenvolvimento',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'Perfil: ${widget.perfil.tipo?.toUpperCase() ?? 'N/A'}\n'
              'ID: ${widget.perfil.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ [MainNavigatorScreen] build - Reconstruindo a tela');
    
    final navItems = _buildNavItemsForProfile(widget.perfil.tipo);
    
    if (navItems.isEmpty) {
      print('❌ [MainNavigatorScreen] ERRO: Nenhum item de navegação disponível para o perfil: ${widget.perfil.tipo}');
      return const Scaffold(
        body: Center(child: Text('Navegação não disponível para este perfil')),
      );
    }
    
    print('🔍 [MainNavigatorScreen] Índice selecionado: $_selectedIndex');
    print('🔍 [MainNavigatorScreen] Página atual: ${_getPageName(_pages[_selectedIndex])}');
    
    // Debug log para verificar o tipo do perfil
    print('ℹ️ [MainNavigatorScreen] Tipo do perfil: ${widget.perfil.tipo}');
    print('ℹ️ [MainNavigatorScreen] Páginas disponíveis: ${_pages.length}');

    // Se o perfil for null ou desconhecido, mostramos uma tela de fallback.
    final tipoLower = widget.perfil.tipo?.toLowerCase();
    if (tipoLower == null || (tipoLower != 'individual' && tipoLower != 'familiar' && tipoLower != 'idoso')) {
      print('⚠️ [MainNavigatorScreen] ATENÇÃO: Mostrando tela de fallback para tipo desconhecido: ${widget.perfil.tipo}');
      return Scaffold(
        appBar: AppBar(title: const Text('CareMind')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Tipo de perfil não suportado.'),
              const SizedBox(height: 16),
              Text('Tipo: ${widget.perfil.tipo ?? 'nulo'}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('ID: ${widget.perfil.id}'),
            ],
          ),
        ),
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
          items: navItems,
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
