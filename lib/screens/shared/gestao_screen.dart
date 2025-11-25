import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/state/familiar_state.dart';
import '../../core/injection/injection.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/banner_contexto_familiar.dart';
import '../medication/gestao_medicamentos_screen.dart';
import '../rotinas/gestao_rotinas_screen.dart';
import '../compromissos/gestao_compromissos_screen.dart';
import '../medication/add_edit_medicamento_form.dart';
import '../rotinas/add_edit_rotina_form.dart';
import '../compromissos/add_edit_compromisso_form.dart';
import '../shared/alertas_screen.dart';
import '../../core/navigation/app_navigation.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
            }
          },
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0400BA),
          elevation: 4,
          icon: const Icon(Icons.add),
          label: Text(
            'Adicionar',
            style: AppTextStyles.leagueSpartan(
              color: const Color(0xFF0400BA),
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
            }
          },
          backgroundColor: const Color(0xFF0400B9),
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
            }
          },
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0400BA),
          elevation: 4,
          icon: const Icon(Icons.add),
          label: Text(
            'Adicionar',
            style: AppTextStyles.leagueSpartan(
              color: const Color(0xFF0400BA),
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

    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: _getAppBarTitle(),
        isFamiliar: isFamiliar,
      ),
      body: SafeArea(
        child: _currentView == GestaoView.hub
            ? _buildHubView(isFamiliar)
            : _buildSubView(_currentView),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildHubView(bool isFamiliar) {
    return CustomScrollView(
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
                  'O que deseja gerenciar?',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Acesse rapidamente os principais módulos',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75, // Reduzido para dar mais altura aos cards
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildListDelegate([
              _buildGestaoCard(
                title: 'Medicamentos',
                subtitle: 'Gerenciar medicamentos',
                icon: Icons.medication_liquid,
                color: const Color(0xFFE91E63),
                onTap: () => _navigateToView(GestaoView.medicamentos),
              ),
              _buildGestaoCard(
                title: 'Rotinas',
                subtitle: 'Gerenciar rotinas',
                icon: Icons.schedule_rounded,
                color: const Color(0xFFFF9800),
                onTap: () => _navigateToView(GestaoView.rotinas),
              ),
              _buildGestaoCard(
                title: 'Compromissos',
                subtitle: 'Gerenciar compromissos',
                icon: Icons.calendar_today,
                color: const Color(0xFF2196F3),
                onTap: () => _navigateToView(GestaoView.compromissos),
              ),
              _buildGestaoCard(
                title: 'Notificações',
                subtitle: 'Ver alertas e lembretes',
                icon: Icons.notifications_rounded,
                color: const Color(0xFF9C27B0),
                onTap: () {
                  Navigator.push(
                    context,
                    AppNavigation.smoothRoute(
                      const AlertasScreen(),
                    ),
                  );
                },
              ),
            ]),
          ),
        ),
      ],
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
  }) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Text(
              title,
              style: AppTextStyles.leagueSpartan(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              subtitle,
              style: AppTextStyles.leagueSpartan(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

