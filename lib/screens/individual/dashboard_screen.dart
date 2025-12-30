import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';

import '../../core/injection/injection.dart';
import '../../theme/app_theme.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/error_widget_with_retry.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/voice_interface_widget.dart';
import '../../widgets/quick_action_fab.dart';
import '../../widgets/wellbeing_checkin.dart';

import '../../services/supabase_service.dart';
import '../../services/accessibility_service.dart';

import '../../models/perfil.dart';
import '../../models/medicamento.dart';

import '../../providers/dashboard_provider.dart';

import '../medication/add_edit_medicamento_form.dart';

import 'widgets/dashboard_header.dart';
import 'widgets/medication_status_card.dart';
import 'widgets/next_medication_card.dart';
import 'widgets/pending_medications_list.dart';
import 'widgets/upcoming_activities_list.dart';
import 'widgets/empty_state_contextual.dart';

class IndividualDashboardScreen extends ConsumerStatefulWidget {
  const IndividualDashboardScreen({super.key});

  @override
  ConsumerState<IndividualDashboardScreen> createState() => _IndividualDashboardScreenState();
}

class _IndividualDashboardScreenState extends ConsumerState<IndividualDashboardScreen> {
  String _userName = 'Usuário';
  bool _isSelectionMode = false;
  final Map<int, bool> _loadingMedicamentos = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final supabaseService = GetIt.instance<SupabaseService>();
    final user = supabaseService.currentUser;
    if (user != null) {
      final perfil = await supabaseService.getProfile(user.id);
      if (perfil != null && mounted) {
        setState(() => _userName = perfil.nome.split(' ')[0]);
      }
    }
  }

  Future<void> _handleConfirmMedicamento(Medicamento med) async {
    if (med.id == null) return;
    setState(() => _loadingMedicamentos[med.id!] = true);
    await ref.read(dashboardProvider.notifier).toggleMedicamento(med);
    if (mounted) setState(() => _loadingMedicamentos[med.id!] = false);
  }

  Future<void> _handleConfirmBatch(List<Medicamento> meds) async {
    for (var med in meds) {
      if (med.id != null) setState(() => _loadingMedicamentos[med.id!] = true);
    }
    for (var med in meds) {
      await ref.read(dashboardProvider.notifier).toggleMedicamento(med);
    }
    if (mounted) setState(() => _loadingMedicamentos.clear());
    setState(() => _isSelectionMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final supabaseService = GetIt.instance<SupabaseService>();
    final userId = supabaseService.currentUser?.id ?? '';

    return OfflineIndicator(
      child: AppScaffoldWithWaves(
        appBar: const CareMindAppBar(),
        useSolidBackground: true,
        showWaves: false,
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              if (state.errorMessage != null)
                Center(
                  child: ErrorWidgetWithRetry(
                    message: state.errorMessage!,
                    onRetry: () => ref.read(dashboardProvider.notifier).loadData(),
                  ),
                )
              else if (state.isLoading)
                const SingleChildScrollView(child: DashboardSkeletonLoader())
              else
                RefreshIndicator(
                  onRefresh: () => ref.read(dashboardProvider.notifier).loadData(),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: DashboardHeader(
                            userName: _userName,
                            isOffline: state.isOffline,
                            onReadSummary: _readSummary,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: _buildWellbeingCheckin(userId),
                        ),
                      ),
                      if (state.totalMedicamentos == 0 && state.rotinas.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: EmptyStateContextual(userId: userId),
                          ),
                        )
                      else ...[
                        _buildAnimatedSliver(
                          child: MedicationStatusCard(
                            medicamentosTomados: state.medicamentosTomados,
                            totalMedicamentos: state.totalMedicamentos,
                            temAtraso: _checkAtraso(state),
                            mensagemStatus: _getMensagemStatus(state),
                          ),
                        ),
                        _buildAnimatedSliver(
                          delay: 100,
                          child: NextMedicationCard(
                            proximoMedicamento: _calcularProximo(state),
                            proximoHorario: _calcularProximoHorario(state),
                          ),
                        ),
                        if (state.medicamentosPendentes.isNotEmpty)
                          _buildAnimatedSliver(
                            delay: 200,
                            child: PendingMedicationsList(
                              medicamentosPendentes: state.medicamentosPendentes,
                              statusMedicamentos: state.statusMedicamentos,
                              loadingMedicamentos: _loadingMedicamentos,
                              onConfirmSingle: _handleConfirmMedicamento,
                              onConfirmBatch: _handleConfirmBatch,
                              isSelectionMode: _isSelectionMode,
                              onToggleSelectionMode: () => setState(() => _isSelectionMode = !_isSelectionMode),
                            ),
                          ),
                        _buildAnimatedSliver(
                          delay: 300,
                          child: UpcomingActivitiesList(rotinas: state.rotinas),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              if (userId.isNotEmpty && !state.isLoading) ...[
                VoiceInterfaceWidget(userId: userId, showAsFloatingButton: true),
                Positioned(bottom: 80, right: 24, child: _buildFAB(context)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSliver({required Widget child, int delay = 0}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: child.animate().fadeIn(duration: 400.ms, delay: delay.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
      ),
    );
  }

  Widget _buildWellbeingCheckin(String userId) {
    return FutureBuilder<Perfil?>(
      future: GetIt.instance<SupabaseService>().getProfile(userId),
      builder: (context, snapshot) => snapshot.data != null ? WellbeingCheckin(perfilId: snapshot.data!.id) : const SizedBox.shrink(),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return QuickActionFAB(
      onMedicationTap: () async {
        final result = await context.push('/gestao-medicamentos');
        if (result == true) ref.read(dashboardProvider.notifier).loadData();
      },
      onVitalSignTap: () {
        FeedbackService.showInfo(context, 'Funcionalidade de Sinais Vitais em desenvolvimento.');
      },
      onEventTap: () async {
        final result = await context.push('/registrar-evento');
        if (result == true) ref.read(dashboardProvider.notifier).loadData();
      },
    );
  }

  void _readSummary() {
    final state = ref.read(dashboardProvider);
    final text = 'Olá $_userName, você já tomou ${state.medicamentosTomados} de ${state.totalMedicamentos} medicamentos hoje.';
    AccessibilityService.speak(text);
  }

  bool _checkAtraso(DashboardState state) {
    return false; 
  }

  String _getMensagemStatus(DashboardState state) {
    if (state.totalMedicamentos == 0) return 'Nenhum medicamento hoje';
    if (state.medicamentosTomados == state.totalMedicamentos) return 'Tudo em dia!';
    return 'Você tem pendências';
  }

  Medicamento? _calcularProximo(DashboardState state) {
    if (state.medicamentosPendentes.isEmpty) return null;
    return state.medicamentosPendentes.first;
  }

  TimeOfDay? _calcularProximoHorario(DashboardState state) => null;
}
