import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/compromisso.dart';
import '../core/errors/app_exception.dart';
import 'accessibility_service.dart';
import 'supabase_service.dart';

class AppointmentCRUDService extends ChangeNotifier {
  final SupabaseService _supabaseService;
  List<Compromisso> _appointments = [];
  bool _isLoading = false;
  String? _lastError;

  AppointmentCRUDService(this._supabaseService);

  List<Compromisso> get appointments => List.unmodifiable(_appointments);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get hasAppointments => _appointments.isNotEmpty;
  int get appointmentCount => _appointments.length;

  Future<List<Compromisso>> loadAppointments() async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw const AuthenticationException(message: 'Usuário não autenticado');
      }

      final perfil = await _supabaseService.getProfile(user.id);
      if (perfil == null) {
        throw Exception('Perfil não encontrado');
      }

      final response = await _supabaseService.client
          .from('compromissos')
          .select()
          .eq('perfil_id', perfil.id)
          .order('data_hora', ascending: true);

      _appointments =
          (response as List).map((json) => Compromisso.fromMap(json)).toList();

      await AccessibilityService.speak(_appointments.isEmpty
          ? 'Nenhum compromisso encontrado.'
          : 'Carregados ${_appointments.length} compromissos.');

      notifyListeners();
      return _appointments;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak(
          'Erro ao carregar compromissos: ${e.toString()}');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  Future<Compromisso?> createAppointment({
    required String titulo,
    String? descricao,
    required DateTime dataHora,
    String? local,
    String? tipo,
    int? lembreteMinutos,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw const AuthenticationException(message: 'Usuário não autenticado');
      }

      await AccessibilityService.speak('Adicionando compromisso: $titulo...');

      final perfil = await _supabaseService.getProfile(user.id);
      if (perfil == null) {
        throw Exception('Perfil não encontrado');
      }

      final appointmentData = {
        'perfil_id': perfil.id,
        'titulo': titulo.trim(),
        'descricao': descricao?.trim(),
        'data_hora': dataHora.toIso8601String(),
        'local': local?.trim(),
        'tipo': tipo,
        'lembrete_minutos': lembreteMinutos ?? 60,
      };

      final response = await _supabaseService.client
          .from('compromissos')
          .insert(appointmentData)
          .select()
          .single();

      final newAppointment = Compromisso.fromMap(response);
      _appointments.add(newAppointment);
      _appointments.sort((a, b) => a.dataHora.compareTo(b.dataHora));

      await AccessibilityService.speak(
          'Compromisso $titulo adicionado com sucesso!');

      notifyListeners();
      return newAppointment;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak(
          'Erro ao adicionar compromisso: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateAppointment({
    required String id,
    String? titulo,
    String? descricao,
    DateTime? dataHora,
    String? local,
    String? tipo,
    int? lembreteMinutos,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final appointmentIndex = _appointments.indexWhere((a) => a.id == id);
      if (appointmentIndex == -1) {
        throw const ValidationException(message: 'Compromisso não encontrado');
      }

      await AccessibilityService.speak('Atualizando compromisso...');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (titulo != null) updateData['titulo'] = titulo.trim();
      if (descricao != null) updateData['descricao'] = descricao.trim();
      if (dataHora != null)
        updateData['data_hora'] = dataHora.toIso8601String();
      if (local != null) updateData['local'] = local.trim();
      if (tipo != null) updateData['tipo'] = tipo;
      if (lembreteMinutos != null)
        updateData['lembrete_minutos'] = lembreteMinutos;

      final response = await _supabaseService.client
          .from('compromissos')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      final updatedAppointment = Compromisso.fromMap(response);
      _appointments[appointmentIndex] = updatedAppointment;
      _appointments.sort((a, b) => a.dataHora.compareTo(b.dataHora));

      await AccessibilityService.speak('Compromisso atualizado com sucesso!');

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak(
          'Erro ao atualizar compromisso: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAppointment(String id) async {
    _setLoading(true);
    _clearError();

    try {
      final appointment = _appointments.firstWhere(
        (a) => a.id == id,
        orElse: () => throw const ValidationException(
            message: 'Compromisso não encontrado'),
      );

      await AccessibilityService.speak(
          'Excluindo compromisso: ${appointment.titulo}');

      await _supabaseService.client.from('compromissos').delete().eq('id', id);

      _appointments.removeWhere((a) => a.id == id);

      await AccessibilityService.speak(
          'Compromisso ${appointment.titulo} excluído com sucesso!');

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak(
          'Erro ao excluir compromisso: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  List<Compromisso> searchAppointments(String term) {
    if (term.isEmpty) return _appointments;

    final searchTerm = term.toLowerCase();
    final results = _appointments.where((appointment) {
      return appointment.titulo.toLowerCase().contains(searchTerm) ||
          (appointment.local?.toLowerCase().contains(searchTerm) ?? false) ||
          (appointment.descricao?.toLowerCase().contains(searchTerm) ?? false);
    }).toList();

    AccessibilityService.speak(results.isEmpty
        ? 'Nenhum compromisso encontrado para: $term'
        : 'Encontrados ${results.length} compromissos para: $term');

    return results;
  }

  List<Compromisso> getTodayAppointments() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _appointments.where((a) {
      final appointmentDate =
          DateTime(a.dataHora.year, a.dataHora.month, a.dataHora.day);
      return appointmentDate.isAtSameMomentAs(today);
    }).toList();
  }

  List<Compromisso> getUpcomingAppointments() {
    final now = DateTime.now();
    final next24Hours = now.add(const Duration(hours: 24));

    return _appointments.where((a) {
      return a.dataHora.isAfter(now) && a.dataHora.isBefore(next24Hours);
    }).toList();
  }

  String? validateAppointment({
    required String titulo,
    required DateTime dataHora,
  }) {
    if (titulo.trim().isEmpty) {
      return 'Título do compromisso é obrigatório';
    }
    return null;
  }

  Future<void> announceAppointmentDetails(Compromisso appointment) async {
    final message = '''
      Informações do compromisso:
      Título: ${appointment.titulo}
      Data e Hora: ${_formatDateTime(appointment.dataHora)}
      Local: ${appointment.local ?? 'Não informado'}
      ${appointment.descricao != null ? 'Descrição: ${appointment.descricao}' : ''}
    ''';

    await AccessibilityService.speak(message.trim());
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day;
    final month = dateTime.month;
    final year = dateTime.year;
    final hour = dateTime.hour;
    final minute = dateTime.minute;

    final monthNames = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro'
    ];

    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return '$day de ${monthNames[month - 1]} de $year às $timeStr';
  }

  void clearAppointments() {
    _appointments.clear();
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
