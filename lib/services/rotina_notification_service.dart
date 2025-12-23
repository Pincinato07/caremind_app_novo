import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';
import 'rotina_analytics_service.dart';
import '../core/injection/injection.dart';

/// Serviço de Notificações para Rotinas
///
/// Agenda notificações baseadas na frequência das rotinas:
/// - Diário: notificações nos horários especificados
/// - Intervalo: notificações a cada X horas a partir de um horário inicial
/// - Dias alternados: notificações a cada X dias no horário especificado
/// - Semanal: notificações nos dias da semana especificados
class RotinaNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ID do canal Android para rotinas
  static const String _rotinaChannelId = 'lembrete_rotina_channel';
  static const String _rotinaChannelName = 'Lembretes de Rotinas';
  static const String _rotinaChannelDescription =
      'Notificações de horários de rotinas com som e vibração';

  /// Inicializar canal de notificações para rotinas
  static Future<void> initializeChannel() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation == null) return;

    const channel = AndroidNotificationChannel(
      _rotinaChannelId,
      _rotinaChannelName,
      description: _rotinaChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      bypassDnd: true,
    );

    await androidImplementation.createNotificationChannel(channel);
    debugPrint('✅ Canal de notificações de rotinas criado: $_rotinaChannelId');
  }

  /// Agendar notificações para uma rotina baseado na sua frequência
  static Future<void> scheduleRotinaNotifications(
      Map<String, dynamic> rotina) async {
    try {
      final rotinaId = rotina['id'] as int?;
      if (rotinaId == null) {
        debugPrint('⚠️ Não é possível agendar: rotina sem ID');
        return;
      }

      // Verificar se notificações de rotinas estão habilitadas
      try {
        final settingsService = getIt<SettingsService>();
        if (!settingsService.notificationsRotinas) {
          debugPrint('ℹ️ Notificações de rotinas desabilitadas pelo usuário');
          return;
        }
      } catch (e) {
        // SettingsService pode não estar disponível, continuar mesmo assim
        debugPrint('⚠️ SettingsService não disponível: $e');
      }

      // Garantir que o canal está criado
      await initializeChannel();

      // Cancelar notificações antigas desta rotina
      await _cancelRotinaNotifications(rotinaId);

      final frequencia = rotina['frequencia'] as Map<String, dynamic>?;
      if (frequencia == null) {
        debugPrint('⚠️ Rotina ${rotina['titulo']}: Sem frequência definida');
        return;
      }

      final tipo = frequencia['tipo'] as String?;
      if (tipo == null) {
        debugPrint('⚠️ Rotina ${rotina['titulo']}: Tipo de frequência inválido');
        return;
      }

      final titulo = rotina['titulo'] as String? ?? 'Rotina';
      final descricao = rotina['descricao'] as String?;

      final perfilId = rotina['perfil_id'] as String?;

      switch (tipo) {
        case 'diario':
          await _scheduleDiario(rotinaId, titulo, descricao, frequencia, perfilId);
          break;
        case 'intervalo':
          await _scheduleIntervalo(rotinaId, titulo, descricao, frequencia, perfilId);
          break;
        case 'dias_alternados':
          await _scheduleDiasAlternados(
              rotinaId, titulo, descricao, frequencia, perfilId);
          break;
        case 'semanal':
          await _scheduleSemanal(rotinaId, titulo, descricao, frequencia, perfilId);
          break;
        default:
          debugPrint('⚠️ Tipo de frequência não suportado: $tipo');
      }

      // Rastrear analytics de agendamento de notificações
      try {
        final frequencia = rotina['frequencia'] as Map<String, dynamic>?;
        final tipoFrequencia = frequencia?['tipo'] as String? ?? 'desconhecido';
        await RotinaAnalyticsService.trackNotificacaoEnviada(
          rotinaId: rotina['id'] as int,
          tipoFrequencia: tipoFrequencia,
          perfilId: rotina['perfil_id'] as String?,
        );
      } catch (e) {
        debugPrint('⚠️ Erro ao rastrear analytics de notificação: $e');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao agendar notificações de rotina: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Agendar notificações diárias
  static Future<void> _scheduleDiario(
    int rotinaId,
    String titulo,
    String? descricao,
    Map<String, dynamic> frequencia,
    String? perfilId,
  ) async {
    final horarios = frequencia['horarios'] as List?;
    if (horarios == null || horarios.isEmpty) {
      debugPrint('⚠️ Rotina $titulo: Nenhum horário encontrado');
      return;
    }

    for (int index = 0; index < horarios.length; index++) {
      final horarioStr = horarios[index].toString();
      final horario = _parseTimeOfDay(horarioStr);
      if (horario == null) continue;

      final notificationId = _generateNotificationId(rotinaId, index);
      await _scheduleSingleReminder(
        id: notificationId,
        rotinaId: rotinaId,
        titulo: titulo,
        descricao: descricao,
        horario: horario,
      );
    }

      debugPrint(
          '✅ ${horarios.length} notificação(ões) agendada(s) para rotina: $titulo');
  }

  /// Agendar notificações com intervalo de horas
  static Future<void> _scheduleIntervalo(
    int rotinaId,
    String titulo,
    String? descricao,
    Map<String, dynamic> frequencia,
    String? perfilId,
  ) async {
    final intervaloHoras = frequencia['intervalo_horas'] as int? ?? 8;
    final inicioStr = frequencia['inicio'] as String?;
    if (inicioStr == null || inicioStr.isEmpty) {
      debugPrint('⚠️ Rotina $titulo: Horário de início não especificado');
      return;
    }

    final inicio = _parseTimeOfDay(inicioStr);
    if (inicio == null) {
      debugPrint('⚠️ Rotina $titulo: Horário de início inválido');
      return;
    }

    // Agendar notificações a cada X horas a partir do horário inicial
    // Limitar a 4 notificações por dia (24h / intervalo)
    final maxNotificacoes = (24 / intervaloHoras).ceil();

    for (int i = 0; i < maxNotificacoes; i++) {
      final horasAdicionais = i * intervaloHoras;
      final horario = TimeOfDay(
        hour: (inicio.hour + horasAdicionais) % 24,
        minute: inicio.minute,
      );

      final notificationId = _generateNotificationId(rotinaId, i);
      await _scheduleSingleReminder(
        id: notificationId,
        rotinaId: rotinaId,
        titulo: titulo,
        descricao: descricao,
        horario: horario,
      );
    }

      debugPrint(
          '✅ $maxNotificacoes notificação(ões) agendada(s) para rotina: $titulo (intervalo: ${intervaloHoras}h)');
      
      // Rastrear analytics
      try {
        await RotinaAnalyticsService.trackNotificacaoEnviada(
          rotinaId: rotinaId,
          tipoFrequencia: 'intervalo',
          perfilId: perfilId,
        );
      } catch (e) {
        debugPrint('⚠️ Erro ao rastrear analytics de notificação: $e');
      }
  }

  /// Agendar notificações em dias alternados
  static Future<void> _scheduleDiasAlternados(
    int rotinaId,
    String titulo,
    String? descricao,
    Map<String, dynamic> frequencia,
    String? perfilId,
  ) async {
    final intervaloDias = frequencia['intervalo_dias'] as int? ?? 2;
    final horarioStr = frequencia['horario'] as String?;
    if (horarioStr == null || horarioStr.isEmpty) {
      debugPrint('⚠️ Rotina $titulo: Horário não especificado');
      return;
    }

    final horario = _parseTimeOfDay(horarioStr);
    if (horario == null) {
      debugPrint('⚠️ Rotina $titulo: Horário inválido');
      return;
    }

    // Agendar para os próximos 30 dias
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    int count = 0;

    for (int i = 0; i < 30; i += intervaloDias) {
      final data = hoje.add(Duration(days: i));
      final dataHora = DateTime(
        data.year,
        data.month,
        data.day,
        horario.hour,
        horario.minute,
      );

      // Só agendar se for no futuro
      if (dataHora.isAfter(agora)) {
        final notificationId = _generateNotificationId(rotinaId, count);
        await _scheduleSingleReminderAtDate(
          id: notificationId,
          rotinaId: rotinaId,
          titulo: titulo,
          descricao: descricao,
          dataHora: dataHora,
        );
        count++;
      }
    }

    debugPrint(
        '✅ $count notificação(ões) agendada(s) para rotina: $titulo (a cada $intervaloDias dias)');
  }

  /// Agendar notificações semanais
  static Future<void> _scheduleSemanal(
    int rotinaId,
    String titulo,
    String? descricao,
    Map<String, dynamic> frequencia,
    String? perfilId,
  ) async {
    final diasSemana = frequencia['dias_da_semana'] as List?;
    final horarioStr = frequencia['horario'] as String?;

    if (diasSemana == null || diasSemana.isEmpty) {
      debugPrint('⚠️ Rotina $titulo: Nenhum dia da semana especificado');
      return;
    }

    if (horarioStr == null || horarioStr.isEmpty) {
      debugPrint('⚠️ Rotina $titulo: Horário não especificado');
      return;
    }

    final horario = _parseTimeOfDay(horarioStr);
    if (horario == null) {
      debugPrint('⚠️ Rotina $titulo: Horário inválido');
      return;
    }

    // Agendar para os próximos 4 semanas
    final agora = DateTime.now();
    int count = 0;

    for (int semana = 0; semana < 4; semana++) {
      for (final diaNum in diasSemana) {
        final dia = diaNum as int; // 1 = Segunda, 7 = Domingo
        final diasAteDia = (dia - agora.weekday + 7) % 7;
        final diasOffset = semana * 7 + (diasAteDia == 0 && agora.weekday == dia
            ? 7
            : diasAteDia);

        final hoje = DateTime(agora.year, agora.month, agora.day);
        final data = hoje.add(Duration(days: diasOffset));
        final dataHora = DateTime(
          data.year,
          data.month,
          data.day,
          horario.hour,
          horario.minute,
        );

        // Só agendar se for no futuro
        if (dataHora.isAfter(agora)) {
          final notificationId = _generateNotificationId(rotinaId, count);
          await _scheduleSingleReminderAtDate(
            id: notificationId,
            rotinaId: rotinaId,
            titulo: titulo,
            descricao: descricao,
            dataHora: dataHora,
          );
          count++;
        }
      }
    }

    debugPrint(
        '✅ $count notificação(ões) agendada(s) para rotina: $titulo (semanal)');
  }

  /// Agendar uma única notificação repetitiva (para diário)
  static Future<void> _scheduleSingleReminder({
    required int id,
    required int rotinaId,
    required String titulo,
    String? descricao,
    required TimeOfDay horario,
  }) async {
    try {
      final agora = DateTime.now();
      var dataHora = DateTime(
        agora.year,
        agora.month,
        agora.day,
        horario.hour,
        horario.minute,
      );

      if (dataHora.isBefore(agora)) {
        dataHora = dataHora.add(const Duration(days: 1));
      }

      final tzDateTime = tz.TZDateTime.from(dataHora, tz.local);

      final saudacao = _getSaudacao(horario.hour);
      final tituloNotificacao = '$saudacao Hora da $titulo!';
      final corpo = descricao ?? 'Não esqueça de realizar sua rotina. 💪';

      final androidDetails = AndroidNotificationDetails(
        _rotinaChannelId,
        _rotinaChannelName,
        channelDescription: _rotinaChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        styleInformation: BigTextStyleInformation(
          corpo,
          contentTitle: tituloNotificacao,
          summaryText: 'CareMind - Lembrete de Rotina',
        ),
        ongoing: false,
        autoCancel: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        ticker: 'Lembrete: $titulo',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        tituloNotificacao,
        corpo,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: rotinaId.toString(),
      );

      debugPrint(
          '✅ Notificação agendada: ID=$id, Horário=${horario.hour}:${horario.minute.toString().padLeft(2, '0')}, Rotina=$titulo');
    } catch (e) {
      debugPrint(
          '❌ Erro ao agendar notificação para $titulo no horário ${horario.hour}:${horario.minute} - $e');
    }
  }

  /// Agendar uma única notificação em data específica (para dias alternados e semanal)
  static Future<void> _scheduleSingleReminderAtDate({
    required int id,
    required int rotinaId,
    required String titulo,
    String? descricao,
    required DateTime dataHora,
  }) async {
    try {
      final tzDateTime = tz.TZDateTime.from(dataHora, tz.local);

      final saudacao = _getSaudacao(dataHora.hour);
      final tituloNotificacao = '$saudacao Hora da $titulo!';
      final corpo = descricao ?? 'Não esqueça de realizar sua rotina. 💪';

      final androidDetails = AndroidNotificationDetails(
        _rotinaChannelId,
        _rotinaChannelName,
        channelDescription: _rotinaChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        styleInformation: BigTextStyleInformation(
          corpo,
          contentTitle: tituloNotificacao,
          summaryText: 'CareMind - Lembrete de Rotina',
        ),
        ongoing: false,
        autoCancel: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        ticker: 'Lembrete: $titulo',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        tituloNotificacao,
        corpo,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: rotinaId.toString(),
      );

      debugPrint(
          '✅ Notificação agendada: ID=$id, Data=${dataHora.toString()}, Rotina=$titulo');
    } catch (e) {
      debugPrint(
          '❌ Erro ao agendar notificação para $titulo em ${dataHora.toString()} - $e');
    }
  }

  /// Cancelar todas as notificações de uma rotina
  static Future<void> cancelRotinaNotifications(int rotinaId) async {
    await _cancelRotinaNotifications(rotinaId);
  }

  static Future<void> _cancelRotinaNotifications(int rotinaId) async {
    // Cancelar até 999 notificações desta rotina
    for (int i = 0; i < 999; i++) {
      final id = _generateNotificationId(rotinaId, i);
      await _notifications.cancel(id);
    }

    debugPrint('🗑️ Notificações canceladas para rotina ID=$rotinaId');
  }

  /// Gerar ID único para notificação
  static int _generateNotificationId(int rotinaId, int index) {
    // Usar range diferente de medicamentos (medicamentos usam * 1000)
    // Rotinas usam * 2000 para evitar conflitos
    return (rotinaId * 2000) + index;
  }

  /// Método público para testes
  static int generateNotificationId(int rotinaId, int index) {
    return _generateNotificationId(rotinaId, index);
  }

  /// Converter string "HH:mm" para TimeOfDay
  static TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao parsear horário: $timeStr - ${e.toString()}');
    }
    return null;
  }

  /// Método público para testes
  static TimeOfDay? parseTimeOfDay(String timeStr) {
    return _parseTimeOfDay(timeStr);
  }

  static String _getSaudacao(int hora) {
    if (hora >= 5 && hora < 12) {
      return '🌅 Bom dia!';
    } else if (hora >= 12 && hora < 18) {
      return '☀️ Boa tarde!';
    } else {
      return '🌙 Boa noite!';
    }
  }
}

