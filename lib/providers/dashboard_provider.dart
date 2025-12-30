import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import '../models/medicamento.dart';
import '../services/supabase_service.dart';
import '../services/medicamento_service.dart';
import '../services/rotina_service.dart';
import '../services/offline_cache_service.dart';
import '../services/historico_eventos_service.dart';

class DashboardState {
  final bool isLoading;
  final String? errorMessage;
  final bool isOffline;
  final List<Medicamento> medicamentosPendentes;
  final List<Map<String, dynamic>> rotinas;
  final Map<int, bool> statusMedicamentos;
  final int totalMedicamentos;
  final int medicamentosTomados;

  DashboardState({
    this.isLoading = true,
    this.errorMessage,
    this.isOffline = false,
    this.medicamentosPendentes = const [],
    this.rotinas = const [],
    this.statusMedicamentos = const {},
    this.totalMedicamentos = 0,
    this.medicamentosTomados = 0,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isOffline,
    List<Medicamento>? medicamentosPendentes,
    List<Map<String, dynamic>>? rotinas,
    Map<int, bool>? statusMedicamentos,
    int? totalMedicamentos,
    int? medicamentosTomados,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isOffline: isOffline ?? this.isOffline,
      medicamentosPendentes: medicamentosPendentes ?? this.medicamentosPendentes,
      rotinas: rotinas ?? this.rotinas,
      statusMedicamentos: statusMedicamentos ?? this.statusMedicamentos,
      totalMedicamentos: totalMedicamentos ?? this.totalMedicamentos,
      medicamentosTomados: medicamentosTomados ?? this.medicamentosTomados,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(DashboardState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);
    
    final isOnline = await OfflineCacheService.isOnline();
    state = state.copyWith(isOffline: !isOnline);

    final supabaseService = GetIt.instance<SupabaseService>();
    final user = supabaseService.currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'Usuário não autenticado');
      return;
    }

    try {
      if (isOnline) {
        await _loadOnlineData(user.id);
      } else {
        await _loadOfflineData(user.id);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _loadOnlineData(String userId) async {
    final medService = GetIt.instance<MedicamentoService>();
    final rotinaService = GetIt.instance<RotinaService>();

    final medsResult = await medService.getMedicamentos(userId);
    final meds = medsResult.when(success: (d) => d, failure: (_) => <Medicamento>[]);
    
    await OfflineCacheService.cacheMedicamentos(userId, meds);

    final status = await HistoricoEventosService.checkMedicamentosConcluidosHoje(
      userId, 
      meds.where((m) => m.id != null).map((m) => m.id!).toList(),
    );

    final rotinas = await rotinaService.getRotinas(userId);
    await OfflineCacheService.cacheRotinas(userId, rotinas);

    state = state.copyWith(
      isLoading: false,
      medicamentosPendentes: meds.where((m) => !(status[m.id] ?? false)).toList(),
      rotinas: rotinas,
      statusMedicamentos: status,
      totalMedicamentos: meds.length,
      medicamentosTomados: meds.where((m) => status[m.id] ?? false).length,
    );
  }

  Future<void> _loadOfflineData(String userId) async {
    final cachedMeds = await OfflineCacheService.getCachedMedicamentos(userId);
    final cachedRotinas = await OfflineCacheService.getCachedRotinas(userId);

    state = state.copyWith(
      isLoading: false,
      isOffline: true,
      medicamentosPendentes: cachedMeds,
      rotinas: cachedRotinas,
      totalMedicamentos: cachedMeds.length,
    );
  }

  Future<void> toggleMedicamento(Medicamento med) async {
    if (med.id == null) return;
    
    final isConcluido = !(state.statusMedicamentos[med.id] ?? false);
    final newStatus = Map<int, bool>.from(state.statusMedicamentos);
    newStatus[med.id!] = isConcluido;

    // UI Progressiva (Optimistic)
    state = state.copyWith(
      statusMedicamentos: newStatus,
      medicamentosTomados: isConcluido ? state.medicamentosTomados + 1 : state.medicamentosTomados - 1,
      medicamentosPendentes: isConcluido 
          ? state.medicamentosPendentes.where((m) => m.id != med.id).toList()
          : [...state.medicamentosPendentes, med],
    );

    try {
      if (state.isOffline) {
        await OfflineCacheService.addPendingAction({
          'type': 'toggle_medicamento',
          'medicamento_id': med.id,
          'concluido': isConcluido,
          'data': DateTime.now().toIso8601String(),
        });
      } else {
        final medService = GetIt.instance<MedicamentoService>();
        await medService.toggleConcluido(med.id!, isConcluido, DateTime.now());
      }
    } catch (e) {
      // Reverter se der erro crítico
      loadData();
    }
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});
