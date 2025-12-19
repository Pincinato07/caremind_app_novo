import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../individual/dashboard_screen.dart';
import '../../medication/gestao_medicamentos_screen.dart';
import '../../individual/rotina_screen.dart';
import '../../shared/gestao_screen.dart';
import '../../organizacao/idosos/idosos_organizacao_lista_screen.dart';
import '../../../widgets/nav_item.dart';
import '../../../widgets/organizacao/context_selector_widget.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/organizacao_provider.dart';

/// Shell de navegação para o perfil INDIVIDUAL
/// BottomBar com 4 itens: Início, Medicamentos, Rotina, Gestão
/// AppBar removida - cada tela filha terá sua própria AppBar
/// Perfil acessível apenas pela AppBar
class IndividualNavigationShell extends ConsumerStatefulWidget {
  const IndividualNavigationShell({super.key});

  @override
  ConsumerState<IndividualNavigationShell> createState() => _IndividualNavigationShellState();
}

class _IndividualNavigationShellState extends ConsumerState<IndividualNavigationShell> {
  int _selectedIndex = 0;

  List<Widget> get _pages {
    final organizacaoState = ref.watch(organizacaoProvider);
    
    // Se o usuário é membro/enfermeiro de organização (não admin), mostrar apenas Lista de Pacientes
    if (organizacaoState.isModoOrganizacao && 
        organizacaoState.roleAtual != null && 
        organizacaoState.roleAtual != 'admin' &&
        organizacaoState.organizacaoAtual?.id != null) {
      return [
        IdososOrganizacaoListaScreen(
          organizacaoId: organizacaoState.organizacaoAtual!.id,
        ),
      ];
    }
    
    // Caso contrário, mostrar todas as telas normais
    return const [
      IndividualDashboardScreen(),
      GestaoMedicamentosScreen(),
      RotinaScreen(),
      GestaoScreen(),
    ];
  }
  
  List<Widget> _buildNavItems() {
    final organizacaoState = ref.watch(organizacaoProvider);
    
    // Se o usuário é membro/enfermeiro de organização (não admin), mostrar apenas Lista de Pacientes
    if (organizacaoState.isModoOrganizacao && 
        organizacaoState.roleAtual != null && 
        organizacaoState.roleAtual != 'admin') {
      return [
        NavItem(
          icon: Icons.people_rounded,
          label: 'Lista de Pacientes',
          isSelected: _selectedIndex == 0,
          onTap: () => _onItemTapped(0),
        ),
      ];
    }
    
    // Caso contrário, mostrar todos os itens normais
    return [
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
        icon: Icons.settings_applications_rounded,
        label: 'Gestão',
        isSelected: _selectedIndex == 3,
        onTap: () => _onItemTapped(3),
      ),
    ];
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
      canPop: true, // ✅ Permitir navegação normal com botão voltar do sistema
      onPopInvoked: (didPop) {
        // Se o usuário tentou voltar mas não conseguiu (raro), 
        // podemos adicionar lógica adicional aqui se necessário
        // Por exemplo: confirmação de saída apenas em casos específicos
      },
      child: ProviderScope(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              const ContextSelectorWidget(),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
              ),
            ],
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
                  children: _buildNavItems(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
