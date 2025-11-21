import 'package:flutter/foundation.dart';
import '../../models/perfil.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';

/// Estado global para gerenciar o contexto do perfil Familiar
/// Armazena o idoso selecionado e notifica mudanças
class FamiliarState extends ChangeNotifier {
  Perfil? _idosoSelecionado;
  List<Perfil> _idososVinculados = [];
  bool _isLoading = false;
  String? _error;

  Perfil? get idosoSelecionado => _idosoSelecionado;
  List<Perfil> get idososVinculados => _idososVinculados;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasIdosos => _idososVinculados.isNotEmpty;

  /// Carrega os idosos vinculados e seleciona o primeiro automaticamente
  Future<void> carregarIdosos(String familiarId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabaseService = getIt<SupabaseService>();
      final idosos = await supabaseService.getIdososVinculados(familiarId);

      _idososVinculados = idosos;

      // Selecionar automaticamente o primeiro idoso se houver
      if (idosos.isNotEmpty && _idosoSelecionado == null) {
        _idosoSelecionado = idosos.first;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Seleciona um idoso específico
  void selecionarIdoso(Perfil idoso) {
    if (_idosoSelecionado?.id != idoso.id) {
      _idosoSelecionado = idoso;
      notifyListeners();
    }
  }

  /// Limpa a seleção (útil para logout)
  void limpar() {
    _idosoSelecionado = null;
    _idososVinculados = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Atualiza a lista de idosos (útil quando um novo idoso é adicionado)
  Future<void> atualizarLista(String familiarId) async {
    await carregarIdosos(familiarId);
  }
}

