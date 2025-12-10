import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/medicamento.dart';
import '../core/errors/app_exception.dart';
import 'accessibility_service.dart';
import 'supabase_service.dart';

class MedicationCRUDService extends ChangeNotifier {
  final SupabaseService _supabaseService;
  List<Medicamento> _medications = [];
  bool _isLoading = false;
  String? _lastError;

  MedicationCRUDService(this._supabaseService);

  List<Medicamento> get medications => List.unmodifiable(_medications);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get hasMedications => _medications.isNotEmpty;
  int get medicationCount => _medications.length;

  Future<List<Medicamento>> loadMedications() async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final perfil = await _supabaseService.getProfile(user.id);
      if (perfil == null) {
        throw Exception('Perfil não encontrado');
      }

      final response = await _supabaseService.client
          .from('medicamentos')
          .select()
          .eq('perfil_id', perfil.id)
          .order('created_at', ascending: false);

      _medications = (response as List)
          .map((json) => Medicamento.fromMap(json))
          .toList();

      await AccessibilityService.speak(
        _medications.isEmpty 
            ? 'Nenhum medicamento encontrado.'
            : 'Carregados ${_medications.length} medicamentos.'
      );

      notifyListeners();
      return _medications;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak('Erro ao carregar medicamentos: ${e.toString()}');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  Future<Medicamento?> createMedication({
    required String nome,
    String? dosagem,
    Map<String, dynamic>? frequencia,
    int? quantidade,
    String? via,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      await AccessibilityService.speak('Adicionando medicamento: $nome...');

      final perfil = await _supabaseService.getProfile(user.id);
      if (perfil == null) {
        throw Exception('Perfil não encontrado');
      }

      final medicationData = {
        'perfil_id': perfil.id,
        'nome': nome.trim(),
        'dosagem': dosagem?.trim(),
        'frequencia': frequencia,
        'quantidade': quantidade,
        'via': via,
      };

      final response = await _supabaseService.client
          .from('medicamentos')
          .insert(medicationData)
          .select()
          .single();

      final newMedication = Medicamento.fromMap(response);
      _medications.insert(0, newMedication);

      await AccessibilityService.speak('Medicamento $nome adicionado com sucesso!');

      notifyListeners();
      return newMedication;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak('Erro ao adicionar medicamento: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateMedication({
    required int id,
    String? nome,
    String? dosagem,
    Map<String, dynamic>? frequencia,
    int? quantidade,
    String? via,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final medicationIndex = _medications.indexWhere((m) => m.id == id);
      if (medicationIndex == -1) {
        throw const ValidationException(message: 'Medicamento não encontrado');
      }
      
      await AccessibilityService.speak('Atualizando medicamento...');

      final updateData = <String, dynamic>{};

      if (nome != null) updateData['nome'] = nome.trim();
      if (dosagem != null) updateData['dosagem'] = dosagem.trim();
      if (frequencia != null) updateData['frequencia'] = frequencia;
      if (quantidade != null) updateData['quantidade'] = quantidade;
      if (via != null) updateData['via'] = via;

      final response = await _supabaseService.client
          .from('medicamentos')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      final updatedMedication = Medicamento.fromMap(response);
      _medications[medicationIndex] = updatedMedication;

      await AccessibilityService.speak('Medicamento atualizado com sucesso!');

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak('Erro ao atualizar medicamento: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteMedication(int id) async {
    _setLoading(true);
    _clearError();

    try {
      final medication = _medications.firstWhere(
        (m) => m.id == id,
        orElse: () => throw const ValidationException(message: 'Medicamento não encontrado'),
      );

      await AccessibilityService.speak('Excluindo medicamento: ${medication.nome}...');

      await _supabaseService.client
          .from('medicamentos')
          .delete()
          .eq('id', id);

      _medications.removeWhere((m) => m.id == id);

      await AccessibilityService.speak('Medicamento ${medication.nome} excluído com sucesso!');

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak('Erro ao excluir medicamento: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  List<Medicamento> searchMedications(String term) {
    if (term.isEmpty) return _medications;

    final searchTerm = term.toLowerCase();
    final results = _medications.where((medication) {
      return medication.nome.toLowerCase().contains(searchTerm) ||
          (medication.dosagem?.toLowerCase().contains(searchTerm) ?? false) ||
          (medication.via?.toLowerCase().contains(searchTerm) ?? false);
    }).toList();

    AccessibilityService.speak(
      results.isEmpty 
          ? 'Nenhum medicamento encontrado para: $term'
          : 'Encontrados ${results.length} medicamentos para: $term'
    );

    return results;
  }

  String? validateMedication({required String nome}) {
    if (nome.trim().isEmpty) {
      return 'Nome do medicamento é obrigatório';
    }
    return null;
  }

  Future<void> announceMedicationDetails(Medicamento medication) async {
    final message = '''
      Informações do medicamento:
      Nome: ${medication.nome}
      ${medication.dosagem != null ? 'Dosagem: ${medication.dosagem}' : ''}
      ${medication.via != null ? 'Via: ${medication.via}' : ''}
      ${medication.quantidade != null ? 'Quantidade: ${medication.quantidade}' : ''}
    ''';

    await AccessibilityService.speak(message.trim());
  }

  Future<void> announceMedicationList([List<Medicamento>? medications]) {
    final list = medications ?? _medications;
    
    if (list.isEmpty) {
      return AccessibilityService.speak('Nenhum medicamento na lista.');
    }

    final message = StringBuffer();
    message.writeln('Lista de medicamentos:');
    
    for (int i = 0; i < list.length; i++) {
      final med = list[i];
      message.writeln('${i + 1}. ${med.nome}${med.dosagem != null ? ', ${med.dosagem}' : ''}');
    }

    return AccessibilityService.speak(message.toString().trim());
  }

  void clearMedications() {
    _medications.clear();
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _lastError = error;
    debugPrint('MedicationCRUDService Error: $error');
    notifyListeners();
  }

  void _clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }
}