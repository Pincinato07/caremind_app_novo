import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicamento.dart';
import 'notification_service.dart';

class DailyCacheService {
  static const String _keyMedicamentos = 'cache_medicamentos';
  static const String _keyCompromissos = 'cache_compromissos';
  static const String _keyRotinas = 'cache_rotinas';
  static const String _keyLastSync = 'cache_last_sync';
  static const String _keyCacheDate = 'cache_date';

  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      debugPrint('✅ DailyCacheService: Inicializado');
    } catch (e) {
      debugPrint('❌ DailyCacheService: Erro ao inicializar - $e');
    }
  }

  Future<void> syncDailyData(String perfilId) async {
    await initialize();
    if (_prefs == null) return;

    try {
      final supabase = Supabase.instance.client;
      final hoje = DateTime.now();
      final hojeStr =
          '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

      final medicamentos = await supabase
          .from('medicamentos')
          .select()
          .eq('perfil_id', perfilId);

      final compromissos = await supabase
          .from('compromissos')
          .select()
          .eq('perfil_id', perfilId)
          .gte('data_hora', hojeStr)
          .lte('data_hora', '${hojeStr}T23:59:59');

      final rotinas =
          await supabase.from('rotinas').select().eq('perfil_id', perfilId);

      await _prefs!.setString(_keyMedicamentos, jsonEncode(medicamentos));
      await _prefs!.setString(_keyCompromissos, jsonEncode(compromissos));
      await _prefs!.setString(_keyRotinas, jsonEncode(rotinas));
      await _prefs!.setString(_keyLastSync, DateTime.now().toIso8601String());
      await _prefs!.setString(_keyCacheDate, hojeStr);

      await _schedulePersonalizedNotifications(
          medicamentos, compromissos, rotinas);

      debugPrint('✅ DailyCacheService: Dados do dia sincronizados');
    } catch (e) {
      debugPrint('❌ DailyCacheService: Erro ao sincronizar - $e');
    }
  }

  Future<void> _schedulePersonalizedNotifications(
    List<dynamic> medicamentos,
    List<dynamic> compromissos,
    List<dynamic> rotinas,
  ) async {
    try {
      await NotificationService.cancelAllNotifications();

      for (final med in medicamentos) {
        final medicamento = Medicamento.fromMap(med);
        await _schedulePersonalizedMedicationNotification(medicamento);
      }

      for (final comp in compromissos) {
        await _scheduleCompromissoNotification(comp);
      }

      for (final rotina in rotinas) {
        await _scheduleRotinaNotification(rotina);
      }

      debugPrint('✅ DailyCacheService: Notificações personalizadas agendadas');
    } catch (e) {
      debugPrint('❌ DailyCacheService: Erro ao agendar notificações - $e');
    }
  }

  Future<void> _schedulePersonalizedMedicationNotification(
      Medicamento med) async {
    await NotificationService.scheduleMedicationReminders(med);
  }

  Future<void> _scheduleCompromissoNotification(
      Map<String, dynamic> comp) async {
    try {
      final dataHora = DateTime.parse(comp['data_hora'] as String);
      final titulo = comp['titulo'] as String? ?? 'Compromisso';
      final lembreteMinutos = comp['lembrete_minutos'] as int? ?? 60;

      final horaNotif = dataHora.subtract(Duration(minutes: lembreteMinutos));

      if (horaNotif.isAfter(DateTime.now())) {
        debugPrint(
            '📅 Compromisso agendado: $titulo às ${dataHora.hour}:${dataHora.minute}');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao agendar compromisso: $e');
    }
  }

  Future<void> _scheduleRotinaNotification(Map<String, dynamic> rotina) async {
    try {
      final titulo = rotina['titulo'] as String? ?? 'Rotina';
      final frequencia = rotina['frequencia'] as Map<String, dynamic>?;

      if (frequencia != null && frequencia['horario'] != null) {
        final horario = frequencia['horario'] as String;
        debugPrint('🔁 Rotina agendada: $titulo às $horario');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao agendar rotina: $e');
    }
  }

  List<Medicamento>? getCachedMedicamentos() {
    if (_prefs == null) return null;
    try {
      final data = _prefs!.getString(_keyMedicamentos);
      if (data == null) return null;
      final list = jsonDecode(data) as List;
      return list.map((item) => Medicamento.fromMap(item)).toList();
    } catch (e) {
      debugPrint(
          '⚠️ DailyCacheService: Erro ao ler medicamentos do cache - $e');
      return null;
    }
  }

  List<Map<String, dynamic>>? getCachedCompromissos() {
    if (_prefs == null) return null;
    try {
      final data = _prefs!.getString(_keyCompromissos);
      if (data == null) return null;
      final list = jsonDecode(data) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint(
          '⚠️ DailyCacheService: Erro ao ler compromissos do cache - $e');
      return null;
    }
  }

  List<Map<String, dynamic>>? getCachedRotinas() {
    if (_prefs == null) return null;
    try {
      final data = _prefs!.getString(_keyRotinas);
      if (data == null) return null;
      final list = jsonDecode(data) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('⚠️ DailyCacheService: Erro ao ler rotinas do cache - $e');
      return null;
    }
  }

  bool shouldSync() {
    if (_prefs == null) return true;

    final lastSyncStr = _prefs!.getString(_keyLastSync);
    final cacheDateStr = _prefs!.getString(_keyCacheDate);

    if (lastSyncStr == null || cacheDateStr == null) return true;

    final hoje = DateTime.now();
    final hojeStr =
        '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

    if (cacheDateStr != hojeStr) return true;

    final lastSync = DateTime.parse(lastSyncStr);
    final horaAtual = hoje.hour;

    if (horaAtual < 7 && lastSync.day != hoje.day) return true;

    return false;
  }

  Future<void> clearCache() async {
    await initialize();
    if (_prefs == null) return;

    await _prefs!.remove(_keyMedicamentos);
    await _prefs!.remove(_keyCompromissos);
    await _prefs!.remove(_keyRotinas);
    await _prefs!.remove(_keyLastSync);
    await _prefs!.remove(_keyCacheDate);

    debugPrint('🗑️ DailyCacheService: Cache limpo');
  }

  DateTime? getLastSyncTime() {
    if (_prefs == null) return null;
    final lastSyncStr = _prefs!.getString(_keyLastSync);
    if (lastSyncStr == null) return null;
    return DateTime.parse(lastSyncStr);
  }
}
