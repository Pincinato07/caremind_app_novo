import 'dart:typed_data' show Int64List;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/medicamento.dart';

/// Serviço de Notificações Locais para Lembretes de Medicamentos
/// 
/// Responsável por agendar notificações diárias repetitivas com som e vibração fortes.
/// Funciona mesmo com o app fechado.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ID do canal Android para medicamentos (CRÍTICO para som e vibração)
  static const String _medicamentoChannelId = 'lembrete_medicamento_channel';
  static const String _medicamentoChannelName = 'Lembretes de Medicamentos';
  static const String _medicamentoChannelDescription =
      'Notificações de horários de medicamentos com som e vibração';

  /// Inicializar o serviço de notificações
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Inicializar timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

      // Configurações Android - CRÍTICO para som e vibração
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configurações iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Inicializar plugin
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized != true) {
        debugPrint('⚠️ NotificationService: Falha ao inicializar notificações');
        return;
      }

      // Criar canal Android com importance.max para som e vibração fortes
      await _createMedicamentoChannel();

      // Solicitar permissões
      await requestPermissions();

      _initialized = true;
      debugPrint('✅ NotificationService: Inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ NotificationService: Erro ao inicializar - $e');
      _initialized = true; // Continua mesmo com erro
    }
  }

  /// Criar canal Android com importância máxima (CRÍTICO)
  /// 
  /// O canal deve ter Importance.max para que as notificações:
  /// - Apareçam como heads-up (popup)
  /// - Toquem som mesmo em modo silencioso (se configurado)
  /// - Vibrem fortemente
  static Future<void> _createMedicamentoChannel() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation == null) return;

    const channel = AndroidNotificationChannel(
      _medicamentoChannelId,
      _medicamentoChannelName,
      description: _medicamentoChannelDescription,
      importance: Importance.max, // CRÍTICO: Máxima importância
      playSound: true, // CRÍTICO: Tocar som
      enableVibration: true, // CRÍTICO: Habilitar vibração
      showBadge: true,
      // Som padrão do sistema (alto)
      // Nota: Se quiser som customizado, adicione arquivo .mp3 em android/app/src/main/res/raw/
    );

    await androidImplementation.createNotificationChannel(channel);
    debugPrint('✅ Canal de notificações criado: $_medicamentoChannelId');
  }

  /// Solicitar permissões necessárias
  /// 
  /// Android 13+ (API 33+): Requer POST_NOTIFICATIONS
  /// iOS: Já solicitado no DarwinInitializationSettings
  static Future<bool> requestPermissions() async {
    // Verificar se já está no Android 13+
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      // Solicitar permissão de notificações no Android 13+
      final granted = await android.requestNotificationsPermission();
      if (granted == true) {
        debugPrint('✅ Permissão de notificações concedida (Android)');
        return true;
      } else {
        debugPrint('⚠️ Permissão de notificações negada (Android)');
        return false;
      }
    }

    // iOS já solicita permissão automaticamente
    return true;
  }

  /// Handler quando usuário toca na notificação
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notificação tocada - ID: ${response.id}, Payload: ${response.payload}');
    // Aqui você pode navegar para a tela de medicamentos
    // O payload contém o ID do medicamento
  }

  /// Agendar lembretes de medicamento (MÉTODO PRINCIPAL)
  /// 
  /// Agenda notificações diárias repetitivas baseadas nos horários do medicamento.
  /// Cada horário gera uma notificação que se repete todos os dias.
  /// 
  /// **Exemplo de uso:**
  /// ```dart
  /// final medicamento = Medicamento(...);
  /// await NotificationService.scheduleMedicationReminders(medicamento);
  /// ```
  static Future<void> scheduleMedicationReminders(Medicamento medicamento) async {
    if (medicamento.id == null) {
      debugPrint('⚠️ Não é possível agendar: medicamento sem ID');
      return;
    }

    if (!_initialized) await initialize();

    // Extrair horários da frequência do medicamento
    final horarios = _extractHorarios(medicamento);

    if (horarios.isEmpty) {
      debugPrint('⚠️ Medicamento ${medicamento.nome}: Nenhum horário encontrado');
      return;
    }

    debugPrint(
      '📅 Agendando ${horarios.length} notificação(ões) para ${medicamento.nome}',
    );

    // Cancelar notificações antigas deste medicamento
    await _cancelMedicamentoNotifications(medicamento.id!);

    // Agendar uma notificação para cada horário
    for (int index = 0; index < horarios.length; index++) {
      final horario = horarios[index];
      final notificationId = _generateNotificationId(medicamento.id!, index);

      await _scheduleSingleReminder(
        id: notificationId,
        medicamento: medicamento,
        horario: horario,
      );
    }

    debugPrint('✅ ${horarios.length} notificação(ões) agendada(s) para ${medicamento.nome}');
  }

  /// Extrair horários da frequência do medicamento
  /// 
  /// Suporta diferentes formatos:
  /// - Frequência diária com horários: `{tipo: 'diario', horarios: ['08:00', '20:00']}`
  /// - Frequência diária com vezes_por_dia: `{tipo: 'diario', vezes_por_dia: 2}` (gera horários padrão)
  /// - Outros formatos serão adaptados conforme necessário
  static List<TimeOfDay> _extractHorarios(Medicamento medicamento) {
    final frequencia = medicamento.frequencia;

    // Caso 1: Horários explícitos
    if (frequencia.containsKey('horarios')) {
      final horariosList = frequencia['horarios'] as List?;
      if (horariosList != null) {
        return horariosList
            .map((h) => _parseTimeOfDay(h.toString()))
            .where((h) => h != null)
            .cast<TimeOfDay>()
            .toList();
      }
    }

    // Caso 2: Frequência diária com vezes_por_dia
    if (frequencia['tipo'] == 'diario') {
      final vezesPorDia = frequencia['vezes_por_dia'] as int? ?? 1;
      return _generateDefaultHorarios(vezesPorDia);
    }

    // Caso 3: Frequência semanal ou personalizada
    // Por padrão, assume 2 vezes por dia (manhã e noite)
    return _generateDefaultHorarios(2);
  }

  /// Gerar horários padrão baseado na quantidade de vezes por dia
  static List<TimeOfDay> _generateDefaultHorarios(int vezesPorDia) {
    final horariosPadrao = [
      const TimeOfDay(hour: 8, minute: 0),   // 08:00 - Manhã
      const TimeOfDay(hour: 14, minute: 0),  // 14:00 - Tarde
      const TimeOfDay(hour: 20, minute: 0),  // 20:00 - Noite
    ];

    return horariosPadrao.take(vezesPorDia).toList();
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
      debugPrint('⚠️ Erro ao parsear horário: $timeStr - $e');
    }
    return null;
  }

  /// Gerar ID único para notificação
  /// 
  /// Formato: medicamentoId * 1000 + indexHorario
  /// Permite até 999 horários por medicamento
  static int _generateNotificationId(int medicamentoId, int horarioIndex) {
    return (medicamentoId * 1000) + horarioIndex;
  }

  /// Agendar uma única notificação repetitiva
  static Future<void> _scheduleSingleReminder({
    required int id,
    required Medicamento medicamento,
    required TimeOfDay horario,
  }) async {
    try {
      // Criar data/hora para hoje no horário especificado
      final agora = DateTime.now();
      var dataHora = DateTime(
        agora.year,
        agora.month,
        agora.day,
        horario.hour,
        horario.minute,
      );

      // Se o horário já passou hoje, agendar para amanhã
      if (dataHora.isBefore(agora)) {
        dataHora = dataHora.add(const Duration(days: 1));
      }

      // Converter para TZDateTime
      final tzDateTime = tz.TZDateTime.from(dataHora, tz.local);

      // Detalhes Android - CRÍTICO: importance.max, som e vibração longa
      final androidDetails = AndroidNotificationDetails(
        _medicamentoChannelId, // Canal com importance.max
        _medicamentoChannelName,
        channelDescription: _medicamentoChannelDescription,
        importance: Importance.max, // CRÍTICO: Máxima importância (heads-up)
        priority: Priority.max, // CRÍTICO: Prioridade máxima
        icon: '@mipmap/ic_launcher',
        playSound: true, // CRÍTICO: Tocar som
        // Som padrão do sistema (alto)
        // Nota: Se quiser som customizado, adicione arquivo .mp3 em android/app/src/main/res/raw/
        enableVibration: true, // CRÍTICO: Habilitar vibração
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]), // CRÍTICO: Vibração longa
        // [0ms espera, 1000ms vibra, 500ms pausa, 1000ms vibra]
        styleInformation: BigTextStyleInformation(
          '${medicamento.nome}\n${medicamento.dosagem}',
          contentTitle: '💊 Hora do Medicamento!',
          summaryText: 'Não esqueça de tomar',
        ),
        ongoing: false, // Permite deslizar para descartar
        autoCancel: true, // Cancela quando toca na notificação
        category: AndroidNotificationCategory.alarm, // Categoria alarme
        visibility: NotificationVisibility.public,
        fullScreenIntent: true, // Mostra em tela cheia se possível
        ticker: 'Hora do medicamento: ${medicamento.nome}',
      );

      // Detalhes iOS
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, // Mostrar alerta
        presentBadge: true, // Mostrar badge
        presentSound: true, // Tocar som
        sound: 'default', // Som padrão do iOS
        interruptionLevel: InterruptionLevel.critical, // CRÍTICO: Máxima interrupção
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Agendar notificação REPETITIVA diária
      await _notifications.zonedSchedule(
        id,
        '💊 Hora do Medicamento!',
        '${medicamento.nome} - ${medicamento.dosagem}',
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // CRÍTICO: Funciona mesmo em modo economia
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // CRÍTICO: Repete diariamente no mesmo horário
        payload: medicamento.id.toString(), // Payload com ID do medicamento
      );

      debugPrint(
        '✅ Notificação agendada: ID=$id, Horário=${horario.hour}:${horario.minute.toString().padLeft(2, '0')}, Medicamento=${medicamento.nome}',
      );
    } catch (e) {
      debugPrint(
        '❌ Erro ao agendar notificação para ${medicamento.nome} no horário ${horario.hour}:${horario.minute} - $e',
      );
    }
  }

  /// Cancelar todas as notificações de um medicamento
  static Future<void> cancelMedicamentoNotifications(int medicamentoId) async {
    await _cancelMedicamentoNotifications(medicamentoId);
  }

  static Future<void> _cancelMedicamentoNotifications(int medicamentoId) async {
    if (!_initialized) await initialize();

    // Cancelar até 999 notificações deste medicamento
    for (int i = 0; i < 999; i++) {
      final id = _generateNotificationId(medicamentoId, i);
      await _notifications.cancel(id);
    }

    debugPrint('🗑️ Notificações canceladas para medicamento ID=$medicamentoId');
  }

  /// Cancelar uma notificação específica por ID
  static Future<void> cancelNotification(int id) async {
    if (!_initialized) await initialize();
    await _notifications.cancel(id);
  }

  /// Cancelar todas as notificações
  static Future<void> cancelAllNotifications() async {
    if (!_initialized) await initialize();
    await _notifications.cancelAll();
    debugPrint('🗑️ Todas as notificações foram canceladas');
  }

  /// Mostrar notificação de teste (para debug)
  static Future<void> showTestNotification({
    String? medicamentoNome,
    String? dosagem,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      _medicamentoChannelId,
      _medicamentoChannelName,
      channelDescription: _medicamentoChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      // Som padrão do sistema
      // Nota: Se quiser som customizado, adicione arquivo .mp3 em android/app/src/main/res/raw/
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      styleInformation: BigTextStyleInformation(
        dosagem ?? 'Teste de notificação',
        contentTitle: '💊 Teste - Hora do Medicamento!',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999999, // ID de teste
      '💊 Teste - Hora do Medicamento!',
      '${medicamentoNome ?? "Medicamento Teste"} - ${dosagem ?? "Dosagem teste"}',
      notificationDetails,
    );
  }
}
