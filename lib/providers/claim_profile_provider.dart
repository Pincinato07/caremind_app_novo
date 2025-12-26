import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/idoso_organizacao_service.dart';
import '../core/injection/injection.dart';
import '../core/errors/app_exception.dart';

/// Estado do ClaimProfile
@immutable
class ClaimProfileState {
  final bool isLoading;
  final bool isSuccess;
  final AppException? error;
  final Map<String, dynamic>? data;
  final String? successMessage;

  const ClaimProfileState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.data,
    this.successMessage,
  });

  /// Estado inicial
  factory ClaimProfileState.initial() {
    return const ClaimProfileState();
  }

  /// Estado de loading
  ClaimProfileState copyWithLoading() {
    return const ClaimProfileState(isLoading: true);
  }

  /// Estado de sucesso
  ClaimProfileState copyWithSuccess(Map<String, dynamic> data, String message) {
    return ClaimProfileState(
      isLoading: false,
      isSuccess: true,
      data: data,
      successMessage: message,
    );
  }

  /// Estado de erro
  ClaimProfileState copyWithError(AppException error) {
    return ClaimProfileState(
      isLoading: false,
      isSuccess: false,
      error: error,
    );
  }

  /// Reseta o estado
  ClaimProfileState copyWithReset() {
    return ClaimProfileState.initial();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClaimProfileState &&
        other.isLoading == isLoading &&
        other.isSuccess == isSuccess &&
        other.error == error &&
        other.data == data &&
        other.successMessage == successMessage;
  }

  @override
  int get hashCode {
    return Object.hash(
      isLoading,
      isSuccess,
      error,
      data,
      successMessage,
    );
  }
}

/// Notifier para gerenciar o estado de Claim Profile
class ClaimProfileNotifier extends StateNotifier<ClaimProfileState> {
  final IdosoOrganizacaoService _idosoService;

  ClaimProfileNotifier(this._idosoService) : super(ClaimProfileState.initial());

  /// Reivindica um perfil (convert ou link_family)
  Future<void> claimProfile({
    required String perfilId,
    required String action,
    required String codigo,
    String? telefone,
  }) async {
    state = state.copyWithLoading();

    final result = await _idosoService.claimProfile(
      perfilId: perfilId,
      action: action,
      codigoVinculacao: codigo,
      telefone: telefone,
    );

    state = result.when(
      success: (data) {
        final message = action == 'convert'
            ? 'Perfil convertido com sucesso!'
            : 'Vínculo familiar criado com sucesso!';
        return state.copyWithSuccess(data, message);
      },
      failure: (exception) => state.copyWithError(exception),
    );
  }

  /// Reseta o estado
  void reset() {
    state = state.copyWithReset();
  }
}

/// Provider do ClaimProfileNotifier
final claimProfileProvider =
    StateNotifierProvider<ClaimProfileNotifier, ClaimProfileState>((ref) {
  final idosoService = getIt<IdosoOrganizacaoService>();
  return ClaimProfileNotifier(idosoService);
});
