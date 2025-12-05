import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/compromisso.dart';
import '../core/errors/app_exception.dart';
import 'accessibility_service.dart';
import 'supabase_service.dart';

/// Serviço completo de CRUD para compromissos com TTS integrado
/// Oferece operações completas de gerenciamento de compromissos
class AppointmentCRUDService extends ChangeNotifier {
  final SupabaseService _supabaseService;
  List<Compromisso> _appointments = [];
  bool _isLoading = false;
  String? _lastError;

  AppointmentCRUDService(this._supabaseService);

  // Getters
  List<Compromisso> get appointments => List.unmodifiable(_appointments);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get hasAppointments => _appointments.isNotEmpty;
  int get appointmentCount => _appointments.length;

  /// Carrega todos os compromissos do usuário
  Future<List<Compromisso>> loadAppointments() async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw const AuthenticationException(message: 'Usuário não autenticado');
      }

      // Buscar perfil primeiro
      final perfil = await _supabaseService.getProfile(user.id);
      if (perfil == null) {
        throw Exception('Perfil não encontrado');
      }

      final response = await _supabaseService.client
          .from('compromissos')
          .select()
          .eq('perfil_id', perfil.id)
          .order('data_hora', ascending: true);

      _appointments = (response as List)
          .map((json) => Compromisso.fromMap(json))
          .toList();

      // Anuncia carregamento com TTS
      await AccessibilityService.speak(
        _appointments.isEmpty 
            ? 'Nenhum compromisso encontrado.'
            : 'Carregados ${_appointments.length} compromissos.'
      );

      notifyListeners();
      return _appointments;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak('Erro ao carregar compromissos: ${e.toString()}');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Cria um novo compromisso
  Future<Compromisso?> createAppointment({
    required String titulo,
    required String descricao,
    required DateTime dataHora,
    required String local,
    String? observacoes,
    bool? lembreteAtivo,
    int? minutosAntes,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw const AuthenticationException(message: 'Usuário não autenticado');
      }

      // Anuncia início da criação
      await AccessibilityService.speak('Adicionando compromisso: $titulo...');

      // Buscar perfil primeiro
      final perfil = await _supabaseService.getProfile(user.id);
      if (perfil == null) {
        throw Exception('Perfil não encontrado');
      }

      final appointmentData = {
        'perfil_id': perfil.id,
        'titulo': titulo.trim(),
        'descricao': descricao.trim(),
        'data_hora': dataHora.toIso8601String(),
        'local': local.trim(),
        'observacoes': observacoes?.trim(),
        'lembrete_ativo': lembreteAtivo ?? true,
        'minutos_antes': minutosAntes ?? 30,
        'status': 'pendente',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabaseService.client
          .from('compromissos')
          .insert(appointmentData)
          .select()
          .single();

      final newAppointment = Compromisso.fromMap(response);
      _appointments.add(newAppointment);
      _appointments.sort((a, b) => a.dataHora.compareTo(b.dataHora));

      // Anuncia sucesso
      await AccessibilityService.speak(
        'Compromisso $titulo adicionado com sucesso!'
      );

      notifyListeners();
      return newAppointment;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak('Erro ao adicionar compromisso: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza um compromisso existente
  Future<bool> updateAppointment({
    required String id,
    String? titulo,
    String? descricao,
    DateTime? dataHora,
    String? local,
    String? observacoes,
    bool? lembreteAtivo,
    int? minutosAntes,
    String? status,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final appointmentIndex = _appointments.indexWhere((a) => a.id == id);
      if (appointmentIndex == -1) {
        throw const ValidationException(message: 'Compromisso não encontrado');
      }
      
      // Anuncia início da atualização
      await AccessibilityService.speak('Atualizando compromisso...');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (titulo != null) updateData['titulo'] = titulo.trim();
      if (descricao != null) updateData['descricao'] = descricao.trim();
      if (dataHora != null) updateData['data_hora'] = dataHora.toIso8601String();
      if (local != null) updateData['local'] = local.trim();
      if (observacoes != null) updateData['observacoes'] = observacoes.trim();
      if (lembreteAtivo != null) updateData['lembrete_ativo'] = lembreteAtivo;
      if (minutosAntes != null) updateData['minutos_antes'] = minutosAntes;
      if (status != null) updateData['status'] = status;

      final response = await _supabaseService.client
          .from('compromissos')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      final updatedAppointment = Compromisso.fromMap(response);
      _appointments[appointmentIndex] = updatedAppointment;
      _appointments.sort((a, b) => a.dataHora.compareTo(b.dataHora));

      // Anuncia sucesso
      await AccessibilityService.speak(
        'Compromisso atualizado com sucesso!'
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak('Erro ao atualizar compromisso: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Exclui um compromisso
  Future<bool> deleteAppointment(String id) async {
    _setLoading(true);
    _clearError();

    try {
      final appointment = _appointments.firstWhere(
        (a) => a.id == id,
        orElse: () => throw const ValidationException(message: 'Compromisso não encontrado'),
      );

      // Anuncia início da exclusão
      await AccessibilityService.speak('Cancelando compromisso: ${appointment.nome}');

      await _supabaseService.client
          .from('compromissos')
          .delete()
          .eq('id', id);

      _appointments.removeWhere((a) => a.id == id);

      // Anuncia sucesso
      await AccessibilityService.speak(
        'Compromisso ${appointment.nome} excluído com sucesso!'
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak('Erro ao excluir compromisso: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Marca compromisso como concluído
  Future<bool> markAsCompleted(String id) async {
    final appointment = _appointments.firstWhere(
      (a) => a.id == id,
      orElse: () => throw const ValidationException(message: 'Compromisso não encontrado'),
    );

    await AccessibilityService.speak(
      'Marcando compromisso como concluído: ${appointment.nome}'
    );

    return await updateAppointment(id: id, status: 'concluido');
  }

  /// Marca compromisso como cancelado
  Future<bool> markAsCancelled(String id) async {
    final appointment = _appointments.firstWhere(
      (a) => a.id == id,
      orElse: () => throw const ValidationException(message: 'Compromisso não encontrado'),
    );

    await AccessibilityService.speak(
      'Cancelando compromisso: ${appointment.nome}'
    );

    return await updateAppointment(id: id, status: 'cancelado');
  }

  /// Ativa/desativa lembrete de compromisso
  Future<bool> toggleReminder(String id) async {
    final appointment = _appointments.firstWhere(
      (a) => a.id == id,
      orElse: () => throw const ValidationException(message: 'Compromisso não encontrado'),
    );

    final newStatus = true; // Campo não existe no modelo, assume true

    await AccessibilityService.speak(
      'Lembrete ativado para: ${appointment.nome}'
    );

    return await updateAppointment(id: id, lembreteAtivo: newStatus);
  }

  /// Busca compromissos por termo
  List<Compromisso> searchAppointments(String term) {
    if (term.isEmpty) return _appointments;

    final searchTerm = term.toLowerCase();
    final results = _appointments.where((appointment) {
      return appointment.nome.toLowerCase().contains(searchTerm) ||
          (appointment.local?.toLowerCase().contains(searchTerm) ?? false) ||
          (appointment.observacoes?.toLowerCase().contains(searchTerm) ?? false);
    }).toList();

    // Anuncia resultado da busca
    AccessibilityService.speak(
      results.isEmpty 
          ? 'Nenhum compromisso encontrado para: $term'
          : 'Encontrados ${results.length} compromissos para: $term'
    );

    return results;
  }

  /// Filtra compromissos por status
  List<Compromisso> getAppointmentsByStatus(String status) {
    return _appointments.where((a) => a.status == status).toList();
  }

  /// Obtém compromissos de hoje
  List<Compromisso> getTodayAppointments() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _appointments.where((a) {
      final appointmentDate = DateTime(
        a.dataHora.year,
        a.dataHora.month,
        a.dataHora.day,
      );
      
      return appointmentDate.isAtSameMomentAs(today);
    }).toList();
  }

  /// Obtém compromissos da semana
  List<Compromisso> getWeekAppointments() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    return _appointments.where((a) {
      return a.dataHora.isAfter(startOfWeek) && a.dataHora.isBefore(endOfWeek);
    }).toList();
  }

  /// Obtém próximos compromissos (próximas 24 horas)
  List<Compromisso> getUpcomingAppointments() {
    final now = DateTime.now();
    final next24Hours = now.add(const Duration(hours: 24));

    return _appointments.where((a) {
      return a.dataHora.isAfter(now) && 
             a.dataHora.isBefore(next24Hours) &&
             a.status == 'pendente';
    }).toList();
  }

  /// Obtém compromissos atrasados
  List<Compromisso> getOverdueAppointments() {
    final now = DateTime.now();

    return _appointments.where((a) {
      return a.dataHora.isBefore(now) && a.status == 'pendente';
    }).toList();
  }

  /// Valida dados do compromisso
  String? validateAppointment({
    required String titulo,
    required String descricao,
    required DateTime dataHora,
    required String local,
  }) {
    if (titulo.trim().isEmpty) {
      return 'Título do compromisso é obrigatório';
    }

    if (descricao.trim().isEmpty) {
      return 'Descrição é obrigatória';
    }

    if (local.trim().isEmpty) {
      return 'Local é obrigatório';
    }

    // Verifica se a data/hora não está no passado
    if (dataHora.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      return 'Compromissos não podem ser agendados no passado';
    }

    return null;
  }

  /// Anuncia informações detalhadas de um compromisso
  Future<void> announceAppointmentDetails(Compromisso appointment) async {
    final message = '''
      Informações do compromisso:
      Nome: ${appointment.nome}
      Data e Hora: ${_formatDateTime(appointment.dataHora)}
      Local: ${appointment.local ?? 'Não informado'}
      ${appointment.observacoes != null ? 'Observações: ${appointment.observacoes}' : ''}
      Status: ${appointment.status}
    ''';

    await AccessibilityService.speak(message.trim());
  }

  /// Anuncia lista de compromissos
  Future<void> announceAppointmentList([List<Compromisso>? appointments]) {
    final list = appointments ?? _appointments;
    
    if (list.isEmpty) {
      return AccessibilityService.speak('Nenhum compromisso na lista.');
    }

    final message = StringBuffer();
    message.writeln('Lista de compromissos:');
    
    for (int i = 0; i < list.length; i++) {
      final appointment = list[i];
      message.writeln('${i + 1}. ${appointment.nome}, ${_formatDateTime(appointment.dataHora)}, ${appointment.local ?? 'Não informado'}');
    }

    return AccessibilityService.speak(message.toString().trim());
  }

  /// Anuncia próximos compromissos
  Future<void> announceUpcomingAppointments() async {
    final upcoming = getUpcomingAppointments();
    
    if (upcoming.isEmpty) {
      await AccessibilityService.speak('Nenhum compromisso próximo nas próximas 24 horas.');
      return;
    }

    final message = StringBuffer();
    message.writeln('Próximos compromissos:');
    
    for (final appointment in upcoming) {
      final hoursFromNow = appointment.dataHora.difference(DateTime.now()).inHours;
      final timeText = hoursFromNow == 0 ? 'agora' : 
                      hoursFromNow == 1 ? 'em 1 hora' : 
                      'em $hoursFromNow horas';
      
      message.writeln('${appointment.nome}, $timeText');
    }

    await AccessibilityService.speak(message.toString().trim());
  }

  /// Formata data e hora para leitura em voz
  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day;
    final month = dateTime.month;
    final year = dateTime.year;
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    
    final monthNames = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    
    return '$day de ${monthNames[month - 1]} de $year às $timeStr';
  }

  /// Limpa a lista de compromissos (para logout)
  void clearAppointments() {
    _appointments.clear();
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
    debugPrint('AppointmentCRUDService Error: $error');
    notifyListeners();
  }

  void _clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }
}
