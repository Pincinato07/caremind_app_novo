import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/medicamento.dart';
import '../core/errors/app_exception.dart';
import 'accessibility_service.dart';
import 'supabase_service.dart';

/// Serviço completo de CRUD para medicamentos com TTS integrado
/// Oferece operações completas de gerenciamento de medicamentos
class MedicationCRUDService extends ChangeNotifier {
  final SupabaseService _supabaseService;
  List<Medicamento> _medications = [];
  bool _isLoading = false;
  String? _lastError;

  MedicationCRUDService(this._supabaseService);

  // Getters
  List<Medicamento> get medications => List.unmodifiable(_medications);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get hasMedications => _medications.isNotEmpty;
  int get medicationCount => _medications.length;

  /// Carrega todos os medicamentos do usuário
  Future<List<Medicamento>> loadMedications() async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final response = await _supabaseService.client
          .from('medicamentos')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      _medications = (response as List)
          .map((json) => Medicamento.fromMap(json))
          .toList();

      // Anuncia carregamento com TTS
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

  /// Cria um novo medicamento
  Future<Medicamento?> createMedication({
    required String nome,
    required String dosagem,
    required String frequencia,
    required String horarios,
    String? observacoes,
    DateTime? dataInicio,
    DateTime? dataFim,
    bool? ativo,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Anuncia início da criação
      await AccessibilityService.speak('Adicionando medicamento: $nome...');

      final medicationData = {
        'user_id': user.id,
        'nome': nome.trim(),
        'dosagem': dosagem.trim(),
        'frequencia': frequencia.trim(),
        'horarios': horarios.trim(),
        'observacoes': observacoes?.trim(),
        'data_inicio': dataInicio?.toIso8601String(),
        'data_fim': dataFim?.toIso8601String(),
        'ativo': ativo ?? true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabaseService.client
          .from('medicamentos')
          .insert(medicationData)
          .select()
          .single();

      final newMedication = Medicamento.fromMap(response);
      _medications.insert(0, newMedication);

      // Anuncia sucesso
      await AccessibilityService.speak(
        'Medicamento $nome adicionado com sucesso!'
      );

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

  /// Atualiza um medicamento existente
  Future<bool> updateMedication({
    required String id,
    String? nome,
    String? dosagem,
    String? frequencia,
    String? horarios,
    String? observacoes,
    DateTime? dataInicio,
    DateTime? dataFim,
    bool? ativo,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final medicationIndex = _medications.indexWhere((m) => m.id == id);
      if (medicationIndex == -1) {
        throw const ValidationException(message: 'Medicamento não encontrado');
      }
      
      // Anuncia início da atualização
      await AccessibilityService.speak('Atualizando medicamento...');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nome != null) updateData['nome'] = nome.trim();
      if (dosagem != null) updateData['dosagem'] = dosagem.trim();
      if (frequencia != null) updateData['frequencia'] = frequencia.trim();
      if (horarios != null) updateData['horarios'] = horarios.trim();
      if (observacoes != null) updateData['observacoes'] = observacoes.trim();
      if (dataInicio != null) updateData['data_inicio'] = dataInicio.toIso8601String();
      if (dataFim != null) updateData['data_fim'] = dataFim.toIso8601String();
      if (ativo != null) updateData['ativo'] = ativo;

      final response = await _supabaseService.client
          .from('medicamentos')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      final updatedMedication = Medicamento.fromMap(response);
      _medications[medicationIndex] = updatedMedication;

      // Anuncia sucesso
      await AccessibilityService.speak(
        'Medicamento atualizado com sucesso!'
      );

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

  /// Exclui um medicamento
  Future<bool> deleteMedication(String id) async {
    _setLoading(true);
    _clearError();

    try {
      final medication = _medications.firstWhere(
        (m) => m.id == id,
        orElse: () => throw const ValidationException(message: 'Medicamento não encontrado'),
      );

      // Anuncia início da exclusão
      await AccessibilityService.speak('Excluindo medicamento: ${medication.nome}...');

      await _supabaseService.client
          .from('medicamentos')
          .delete()
          .eq('id', id);

      _medications.removeWhere((m) => m.id == id);

      // Anuncia sucesso
      await AccessibilityService.speak(
        'Medicamento ${medication.nome} excluído com sucesso!'
      );

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

  /// Ativa/desativa um medicamento
  Future<bool> toggleMedicationStatus(String id) async {
    final medication = _medications.firstWhere(
      (m) => m.id == id,
      orElse: () => throw const ValidationException(message: 'Medicamento não encontrado'),
    );

    final newStatus = !(medication.ativo ?? true);
    final statusText = newStatus ? 'ativado' : 'desativado';

    await AccessibilityService.speak(
      '${statusText[0].toUpperCase() + statusText.substring(1)} medicamento: ${medication.nome}'
    );

    return await updateMedication(id: id, ativo: newStatus);
  }

  /// Busca medicamentos por termo
  List<Medicamento> searchMedications(String term) {
    if (term.isEmpty) return _medications;

    final searchTerm = term.toLowerCase();
    final results = _medications.where((medication) {
      return medication.nome.toLowerCase().contains(searchTerm) ||
          medication.dosagem.toLowerCase().contains(searchTerm) ||
          medication.frequencia['descricao']?.toString().toLowerCase().contains(searchTerm) == true ||
          (medication.observacoes?.toLowerCase().contains(searchTerm) ?? false);
    }).toList();

    // Anuncia resultado da busca
    AccessibilityService.speak(
      results.isEmpty 
          ? 'Nenhum medicamento encontrado para: $term'
          : 'Encontrados ${results.length} medicamentos para: $term'
    );

    return results;
  }

  /// Filtra medicamentos por status
  List<Medicamento> getMedicationsByStatus(bool ativo) {
    return _medications.where((m) => m.ativo == true).toList();
  }

  /// Filtra medicamentos por horário
  List<Medicamento> getMedicationsByTime(String time) {
    return _medications.where((m) =>
        m.horarios?.toLowerCase().contains(time.toLowerCase()) == true
    ).toList();
  }

  /// Obtém medicamentos para hoje
  List<Medicamento> getTodayMedications() {
    final now = DateTime.now();
    return _medications.where((m) {
      if (!(m.ativo ?? true)) return false;
      
      // Verifica se está dentro do período de uso
      if (m.dataInicio != null && now.isBefore(m.dataInicio!)) return false;
      if (m.dataFim != null && now.isAfter(m.dataFim!)) return false;
      
      return true;
    }).toList();
  }

  /// Valida dados do medicamento
  String? validateMedication({
    required String nome,
    required String dosagem,
    required String frequencia,
    required String horarios,
  }) {
    if (nome.trim().isEmpty) {
      return 'Nome do medicamento é obrigatório';
    }

    if (dosagem.trim().isEmpty) {
      return 'Dosagem é obrigatória';
    }

    if (frequencia.trim().isEmpty) {
      return 'Frequência é obrigatória';
    }

    if (horarios.trim().isEmpty) {
      return 'Horários são obrigatórios';
    }

    // Validação básica de horários (formato HH:MM)
    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    final horariosList = horarios.split(',');
    
    for (final horario in horariosList) {
      final trimmedHorario = horario.trim();
      if (!timeRegex.hasMatch(trimmedHorario)) {
        return 'Horário inválido: $trimmedHorario. Use o formato HH:MM.';
      }
    }

    return null;
  }

  /// Anuncia informações detalhadas de um medicamento
  Future<void> announceMedicationDetails(Medicamento medication) async {
    final message = '''
      Informações do medicamento:
      Nome: ${medication.nome}
      Dosagem: ${medication.dosagem}
      Frequência: ${medication.frequencia}
      Horários: ${medication.horarios}
      ${medication.observacoes != null ? 'Observações: ${medication.observacoes}' : ''}
      Status: ${medication.ativo == true ? 'Ativo' : 'Inativo'}
      ${medication.dataInicio != null ? 'Início: ${_formatDate(medication.dataInicio!)}' : ''}
      ${medication.dataFim != null ? 'Fim: ${_formatDate(medication.dataFim!)}' : ''}
    ''';

    await AccessibilityService.speak(message.trim());
  }

  /// Anuncia lista de medicamentos
  Future<void> announceMedicationList([List<Medicamento>? medications]) {
    final list = medications ?? _medications;
    
    if (list.isEmpty) {
      return AccessibilityService.speak('Nenhum medicamento na lista.');
    }

    final message = StringBuffer();
    message.writeln('Lista de medicamentos:');
    
    for (int i = 0; i < list.length; i++) {
      final med = list[i];
      message.writeln('${i + 1}. ${med.nome}, ${med.dosagem}, ${med.horarios}');
    }

    return AccessibilityService.speak(message.toString().trim());
  }

  /// Formata data para leitura em voz
  String _formatDate(DateTime date) {
    final day = date.day;
    final month = date.month;
    final year = date.year;
    
    final monthNames = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    
    return '$day de ${monthNames[month - 1]} de $year';
  }

  /// Limpa a lista de medicamentos (para logout)
  void clearMedications() {
    _medications.clear();
    _clearError();
    notifyListeners();
  }

  // Métodos privados
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
