import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_version.dart';
import '../services/version_sync_service.dart';

/// Estado do sistema de verificação de versão
class VersionCheckState {
  final AppVersion? latestVersion;
  final List<AppVersion>? allVersions;
  final bool isLoading;
  final bool hasNewVersion;
  final bool isBlocked;
  final String? blockReason;
  final String? error;
  final bool syncEnabled;

  VersionCheckState({
    this.latestVersion,
    this.allVersions,
    this.isLoading = false,
    this.hasNewVersion = false,
    this.isBlocked = false,
    this.blockReason,
    this.error,
    this.syncEnabled = true,
  });

  VersionCheckState copyWith({
    AppVersion? latestVersion,
    List<AppVersion>? allVersions,
    bool? isLoading,
    bool? hasNewVersion,
    bool? isBlocked,
    String? blockReason,
    String? error,
    bool? syncEnabled,
  }) {
    return VersionCheckState(
      latestVersion: latestVersion ?? this.latestVersion,
      allVersions: allVersions ?? this.allVersions,
      isLoading: isLoading ?? this.isLoading,
      hasNewVersion: hasNewVersion ?? this.hasNewVersion,
      isBlocked: isBlocked ?? this.isBlocked,
      blockReason: blockReason ?? this.blockReason,
      error: error ?? this.error,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }

  bool get shouldShowBlocker => isBlocked && latestVersion != null;
  bool get shouldShowNotification => hasNewVersion && !isBlocked && latestVersion != null;
  bool get hasData => latestVersion != null;
}

class VersionCheckNotifier extends StateNotifier<VersionCheckState> {
  late final VersionSyncService _service;

  VersionCheckNotifier(SupabaseClient supabase) : super(VersionCheckState()) {
    _service = VersionSyncService(supabase);
  }

  /// Verifica a versão e atualiza o estado
  Future<void> checkVersion() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final latestVersion = await _service.getLatestVersion();
      
      if (latestVersion == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Não foi possível verificar a versão',
        );
        return;
      }

      final hasNew = await _service.hasNewVersion();
      final isBlocked = await _service.isBlocked();
      final blockReason = await _service.getBlockReason();

      // SincronizaDeviceInfo em background
      _service.syncDeviceInfo().catchError((_) {});

      // Registra acesso à versão
      _service.registerVersionAccess().catchError((_) {});

      state = state.copyWith(
        latestVersion: latestVersion,
        isLoading: false,
        hasNewVersion: hasNew,
        isBlocked: isBlocked,
        blockReason: blockReason,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro ao verificar versão: $e',
      );
    }
  }

  /// Busca todas as versões disponíveis
  Future<void> fetchAllVersions() async {
    try {
      final versions = await _service.getAllVersions();
      state = state.copyWith(allVersions: versions);
    } catch (e) {
      print('❌ Erro ao buscar todas as versões: $e');
    }
  }

  /// Marca a versão como vista
  Future<void> markAsSeen() async {
    await _service.markVersionAsSeen();
    await _service.updateLastSync();
    state = state.copyWith(hasNewVersion: false);
  }

  /// Define que o usuário escolheu "lembrar depois"
  Future<void> remindLater() async {
    await _service.setRemindLater();
    await _service.updateLastSync();
    state = state.copyWith(hasNewVersion: false);
  }

  /// Limpa a preferência de "lembrar depois"
  Future<void> clearRemindLater() async {
    await _service.clearRemindLater();
  }

  /// Obtém a versão atual formatada
  Future<String> getCurrentVersion() async {
    return await _service.getCurrentVersionFormatted();
  }

  /// SincronizaDeviceInfo informações do dispositivo
  Future<void> syncDeviceInfo() async {
    try {
      await _service.syncDeviceInfo();
      await _service.updateLastSync();
    } catch (e) {
      print('❌ Erro ao sincronizarDeviceInfo: $e');
    }
  }

  /// Verifica se há sincronização recente
  Future<bool> hasRecentSync() async {
    return await _service.hasRecentSync();
  }
}

/// Provider do estado de verificação de versão
final versionCheckProvider = StateNotifierProvider<VersionCheckNotifier, VersionCheckState>((ref) {
  final supabase = Supabase.instance.client;
  return VersionCheckNotifier(supabase);
});

/// Provider para verificar se deve mostrar o bloqueador
final shouldShowBlockerProvider = Provider<bool>((ref) {
  final state = ref.watch(versionCheckProvider);
  return state.shouldShowBlocker;
});

/// Provider para verificar se deve mostrar a notificação
final shouldShowNotificationProvider = Provider<bool>((ref) {
  final state = ref.watch(versionCheckProvider);
  return state.shouldShowNotification;
});

/// Provider para obter todas as versões (útil para debug/admin)
final allVersionsProvider = Provider<List<AppVersion>?>((ref) {
  final state = ref.watch(versionCheckProvider);
  return state.allVersions;
});
