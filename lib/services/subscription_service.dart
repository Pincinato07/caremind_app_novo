import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class UserPermissions {
  final String nomePlano;
  final bool planoValido;
  final bool permiteOcr;
  final bool permiteAlexa;
  final bool permiteRelatorios;
  final int limiteMedicamentos;
  final int limiteDependentes;
  final String statusAssinatura;

  const UserPermissions({
    required this.nomePlano,
    required this.planoValido,
    required this.permiteOcr,
    required this.permiteAlexa,
    required this.permiteRelatorios,
    required this.limiteMedicamentos,
    required this.limiteDependentes,
    required this.statusAssinatura,
  });

  factory UserPermissions.fromJson(Map<String, dynamic> json) {
    return UserPermissions(
      nomePlano: json['nome_plano'] as String? ?? 'Gratuito',
      planoValido: json['plano_valido'] as bool? ?? true,
      permiteOcr: json['permite_ocr'] as bool? ?? false,
      permiteAlexa: json['permite_alexa'] as bool? ?? false,
      permiteRelatorios: json['permite_relatorios'] as bool? ?? false,
      limiteMedicamentos: json['limite_medicamentos'] as int? ?? 5,
      limiteDependentes: json['limite_dependentes'] as int? ?? 1,
      statusAssinatura: json['status_assinatura'] as String? ?? 'none',
    );
  }

  factory UserPermissions.free() {
    return const UserPermissions(
      nomePlano: 'Gratuito',
      planoValido: true,
      permiteOcr: false,
      permiteAlexa: false,
      permiteRelatorios: false,
      limiteMedicamentos: 5,
      limiteDependentes: 1,
      statusAssinatura: 'none',
    );
  }
}

class SubscriptionService {
  final SupabaseClient _supabase;
  UserPermissions? _cachedPermissions;
  DateTime? _lastFetch;

  static const _cacheDuration = Duration(minutes: 5);

  SubscriptionService(this._supabase);

  Future<UserPermissions> getPermissions({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedPermissions != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cachedPermissions!;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _cachedPermissions = UserPermissions.free();
        return _cachedPermissions!;
      }

      final response = await _supabase
          .from('view_permissoes_usuario')
          .select()
          .eq('usuario_id', userId)
          .single();

      _cachedPermissions = UserPermissions.fromJson(response);
      _lastFetch = DateTime.now();

      return _cachedPermissions!;
    } catch (e) {
      _cachedPermissions = UserPermissions.free();
      return _cachedPermissions!;
    }
  }

  void clearCache() {
    _cachedPermissions = null;
    _lastFetch = null;
  }

  bool get canUseOCR => _cachedPermissions?.permiteOcr ?? false;

  bool get canUseAlexa => _cachedPermissions?.permiteAlexa ?? false;

  bool get canUseReports => _cachedPermissions?.permiteRelatorios ?? false;

  Future<bool> canAddMedicine(int currentCount) async {
    final permissions = await getPermissions();
    return currentCount < permissions.limiteMedicamentos;
  }

  Future<bool> canAddDependent(int currentCount) async {
    final permissions = await getPermissions();
    return currentCount < permissions.limiteDependentes;
  }

  int get limiteMedicamentos => _cachedPermissions?.limiteMedicamentos ?? 5;

  int get limiteDependentes => _cachedPermissions?.limiteDependentes ?? 1;

  String get nomePlano => _cachedPermissions?.nomePlano ?? 'Gratuito';

  bool get isPremium => _cachedPermissions?.nomePlano != 'Gratuito';

  bool get isPending => _cachedPermissions?.statusAssinatura == 'pending';
}
