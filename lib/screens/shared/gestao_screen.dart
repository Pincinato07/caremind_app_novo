import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/state/familiar_state.dart';
import '../../core/injection/injection.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/banner_contexto_familiar.dart';
import '../medication/gestao_medicamentos_screen.dart';
import '../rotinas/gestao_rotinas_screen.dart';
import '../compromissos/gestao_compromissos_screen.dart';
import '../medication/add_edit_medicamento_form.dart';
import '../rotinas/add_edit_rotina_form.dart';
import '../compromissos/add_edit_compromisso_form.dart';
import '../../services/medicamento_service.dart';
import '../../services/rotina_service.dart';
import '../../services/compromisso_service.dart';

/// Tela central de Gestão
/// Acesso rápido a Medicamentos, Rotinas e Compromissos
enum GestaoView { hub, medicamentos, rotinas, compromissos }

class GestaoScreen extends StatefulWidget {
  const GestaoScreen({super.key});

  @override
  State<GestaoScreen> createState() => _GestaoScreenState();
}

class _GestaoScreenState extends State<GestaoScreen> {
  GestaoView _currentView = GestaoView.hub;
  String? _perfilTipo;
  int _refreshKey = 0; // Key para forçar recriação das telas embedded
  
  // Contadores para os cards
  int _medicamentosCount = 0;
  int _rotinasCount = 0;
  int _compromissosCount = 0;
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadCounts();
  }
  
  Future<void> _loadCounts() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final familiarState = getIt<FamiliarState>();
      final user = supabaseService.currentUser;
      
      if (user == null) {
        setState(() => _isLoadingCounts = false);
        return;
      }
      
      String? targetId;
      if (familiarState.hasIdosos && familiarState.idosoSelecionado != null) {
        targetId = familiarState.idosoSelecionado!.id;
      } else {
        targetId = user.id;
      }
      
      final medicamentoService = getIt<MedicamentoService>();
      final rotinaService = getIt<RotinaService>();
      final compromissoService = getIt<CompromissoService>();
      
      final medicamentos = await medicamentoService.getMedicamentos(targetId);
      final rotinas = await rotinaService.getRotinas(targetId);
      final compromissos = await compromissoService.getCompromissos(targetId);
      
      if (mounted) {
        setState(() {
          _medicamentosCount = medicamentos.length;
          _rotinasCount = rotinas.length;
          _compromissosCount = compromissos.length;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCounts = false);
      }
    }
  }

  // Resetar para o hub quando a tela for reconstruída (voltar de outra tela)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Verificar se estamos voltando para esta tela
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      // Se estamos voltando e não estamos no hub, resetar para o hub
      if (_currentView != GestaoView.hub) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentView = GestaoView.hub;
              _refreshKey++; // Incrementar para forçar recriação das sub-telas
            });
          }
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      if (user != null) {
        final perfil = await supabaseService.getProfile(user.id);
        if (perfil != null && mounted) {
          setState(() {
            _perfilTipo = perfil.tipo?.toLowerCase();
          });
        }
      }
    } catch (e) {
      // Ignora erro
    }
  }

  bool get _isIdoso => _perfilTipo == 'idoso';

  void _navigateToView(GestaoView view) {
    setState(() {
      _currentView = view;
    });
  }

  String _getAppBarTitle() {
    switch (_currentView) {
      case GestaoView.medicamentos:
        return 'Medicamentos';
      case GestaoView.rotinas:
        return 'Rotinas';
      case GestaoView.compromissos:
        return 'Compromissos';
      case GestaoView.hub:
        return 'Central de Gestão';
    }
  }

  Widget? _buildFloatingActionButton() {
    // Não mostrar FAB no hub
    if (_currentView == GestaoView.hub) {
      return null;
    }

    // Não mostrar FAB para idosos
    if (_isIdoso) {
      return null;
    }

    final familiarState = getIt<FamiliarState>();
    final idosoId = familiarState.hasIdosos ? familiarState.idosoSelecionado?.id : null;

    switch (_currentView) {
      case GestaoView.medicamentos:
        return FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditMedicamentoForm(idosoId: idosoId),
              ),
            );
            if (result == true && mounted) {
              // Recarregar a tela de medicamentos recriando o widget
              setState(() {
                _refreshKey++;
              });
              _loadCounts(); // Atualizar contadores
            }
          },
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 4,
          icon: const Icon(Icons.add),
          label: Text(
            'Adicionar',
            style: AppTextStyles.leagueSpartan(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        );
      case GestaoView.rotinas:
        return FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditRotinaForm(idosoId: idosoId),
              ),
            );
            if (result == true && mounted) {
              // Recarregar a tela de rotinas recriando o widget
              setState(() {
                _refreshKey++;
              });
              _loadCounts(); // Atualizar contadores
            }
          },
          backgroundColor: AppColors.primary,
          elevation: 4,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Adicionar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        );
      case GestaoView.compromissos:
        return FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditCompromissoForm(idosoId: idosoId),
              ),
            );
            if (result == true && mounted) {
              // Recarregar a tela de compromissos recriando o widget
              setState(() {
                _refreshKey++;
              });
              _loadCounts(); // Atualizar contadores
            }
          },
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 4,
          icon: const Icon(Icons.add),
          label: Text(
            'Adicionar',
            style: AppTextStyles.leagueSpartan(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        );
      case GestaoView.hub:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    final isFamiliar = familiarState.hasIdosos;

    return PopScope(
      canPop: _currentView == GestaoView.hub,
      onPopInvoked: (didPop) {
        if (!didPop && _currentView != GestaoView.hub) {
          // Se não estiver no hub, voltar para o hub
          _navigateToView(GestaoView.hub);
        }
      },
      child: AppScaffoldWithWaves(
        appBar: CareMindAppBar(
          title: _getAppBarTitle(),
          isFamiliar: isFamiliar,
          showBackButton: _currentView != GestaoView.hub,
        ),
        body: SafeArea(
          child: _currentView == GestaoView.hub
              ? _buildHubView(isFamiliar)
              : _buildSubView(_currentView),
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  Future<void> _refreshData() async {
    await _loadCounts();
    // Se estiver em uma sub-view, recarregar também
    if (_currentView != GestaoView.hub) {
      setState(() {
        _refreshKey++;
      });
    }
  }

  Widget _buildHubView(bool isFamiliar) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.white,
      backgroundColor: AppColors.primary,
      strokeWidth: 2.5,
      displacement: 40,
      child: CustomScrollView(
        slivers: [
        // Banner de contexto para perfil familiar
        if (isFamiliar)
          SliverToBoxAdapter(
            child: const BannerContextoFamiliar(),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Central de Gestão',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gerencie medicamentos, rotinas e compromissos',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 8, bottom: AppSpacing.bottomNavBarPadding),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85, // Ajustado para melhor proporção com contadores
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildListDelegate([
              _buildGestaoCard(
                title: 'Medicamentos',
                subtitle: _isLoadingCounts 
                    ? 'Carregando...' 
                    : _medicamentosCount == 0 
                        ? 'Nenhum medicamento' 
                        : '$_medicamentosCount cadastrado${_medicamentosCount > 1 ? 's' : ''}',
                icon: Icons.medication_liquid,
                color: const Color(0xFFE91E63),
                count: _medicamentosCount,
                isLoading: _isLoadingCounts,
                onTap: () => _navigateToView(GestaoView.medicamentos),
              ),
              _buildGestaoCard(
                title: 'Rotinas',
                subtitle: _isLoadingCounts 
                    ? 'Carregando...' 
                    : _rotinasCount == 0 
                        ? 'Nenhuma rotina' 
                        : '$_rotinasCount cadastrada${_rotinasCount > 1 ? 's' : ''}',
                icon: Icons.schedule_rounded,
                color: const Color(0xFFFF9800),
                count: _rotinasCount,
                isLoading: _isLoadingCounts,
                onTap: () => _navigateToView(GestaoView.rotinas),
              ),
              _buildGestaoCard(
                title: 'Compromissos',
                subtitle: _isLoadingCounts 
                    ? 'Carregando...' 
                    : _compromissosCount == 0 
                        ? 'Nenhum compromisso' 
                        : '$_compromissosCount cadastrado${_compromissosCount > 1 ? 's' : ''}',
                icon: Icons.calendar_today,
                color: const Color(0xFF2196F3),
                count: _compromissosCount,
                isLoading: _isLoadingCounts,
                onTap: () => _navigateToView(GestaoView.compromissos),
              ),
            ]),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildSubView(GestaoView view) {
    // Renderizar as telas em modo embedded (sem AppScaffoldWithWaves nem SliverAppBar)
    // pois já estão dentro do AppScaffoldWithWaves da GestaoScreen
    // Usar key para forçar recriação quando necessário (incluindo o view atual na key)
    switch (view) {
      case GestaoView.medicamentos:
        return GestaoMedicamentosScreen(
          key: ValueKey('medicamentos_${_currentView}_$_refreshKey'),
          embedded: true,
        );
      case GestaoView.rotinas:
        return GestaoRotinasScreen(
          key: ValueKey('rotinas_${_currentView}_$_refreshKey'),
          embedded: true,
        );
      case GestaoView.compromissos:
        return GestaoCompromissosScreen(
          key: ValueKey('compromissos_${_currentView}_$_refreshKey'),
          embedded: true,
        );
      case GestaoView.hub:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGestaoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int count = 0,
    bool isLoading = false,
  }) {
    return AnimatedCard(
      index: 0,
      child: CareMindCard(
        variant: CardVariant.glass,
        onTap: onTap,
        padding: AppSpacing.paddingLarge,
        child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top: Ícone e badge de contador
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.small + 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              // Badge de contador
              if (!isLoading && count > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.small - 2, vertical: AppSpacing.xsmall + 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    count.toString(),
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              else if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Bottom: Título e subtítulo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.leagueSpartan(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppTextStyles.leagueSpartan(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}


