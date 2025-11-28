import 'dart:typed_data' show Int64List;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/medicamento.dart';
import 'settings_service.dart';
import '../core/injection/injection.dart';

/// Serviço de Notificações (Locais + Push Remotas FCM) para Lembretes de Medicamentos
/// 
/// Responsável por:
/// - Agendar notificações locais diárias repetitivas com som e vibração fortes
/// - Receber notificações push remotas (FCM) mesmo com o app fechado
/// - Gerenciar tokens FCM e sincronizar com backend
/// 
/// Funciona mesmo com o app fechado através de:
/// - Notificações locais agendadas (flutter_local_notifications)
/// - Push notifications remotas (Firebase Cloud Messaging)
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  // Firebase Messaging
  static FirebaseMessaging? _firebaseMessaging;
  static String? _fcmToken;
  static bool _fcmInitialized = false;

  static bool _initialized = false;
  static SettingsService? _settingsService;
  
  // Callback para quando o token FCM é atualizado (para enviar ao backend)
  static Function(String token)? onFcmTokenUpdated;
  
  // Callback para quando uma notificação FCM chega em foreground
  // Use isso para mostrar in-app notifications
  static Function(RemoteMessage message)? onForegroundMessage;

  /// Obtém o SettingsService (lazy)
  static SettingsService? _getSettingsService() {
    if (_settingsService == null) {
      try {
        _settingsService = getIt<SettingsService>();
      } catch (e) {
        // SettingsService pode não estar disponível ainda
      }
    }
    return _settingsService;
  }

  // ID do canal Android para medicamentos (CRÍTICO para som e vibração)
  static const String _medicamentoChannelId = 'lembrete_medicamento_channel';
  static const String _medicamentoChannelName = 'Lembretes de Medicamentos';
  static const String _medicamentoChannelDescription =
      'Notificações de horários de medicamentos com som e vibração';

  /// Inicializar o serviço de notificações (Locais + FCM)
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

      // Inicializar plugin de notificações locais
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized != true) {
        debugPrint('⚠️ NotificationService: Falha ao inicializar notificações locais');
        return;
      }

      // Criar canal Android com importance.max para som e vibração fortes
      await _createMedicamentoChannel();

      // Solicitar permissões
      await requestPermissions();

      // Inicializar Firebase Messaging (Push Notifications Remotas)
      await _initializeFCM();

      _initialized = true;
      debugPrint('✅ NotificationService: Inicializado com sucesso (Local + FCM)');
    } catch (e) {
      debugPrint('❌ NotificationService: Erro ao inicializar - ${e.toString()}');
      _initialized = true; // Continua mesmo com erro
    }
  }
  
  /// Inicializar Firebase Cloud Messaging (FCM) para Push Notifications Remotas
  static Future<void> _initializeFCM() async {
    try {
      // FCM não funciona na web
      if (kIsWeb) {
        debugPrint('ℹ️ FCM não suportado na web. Apenas notificações locais serão usadas.');
        return;
      }
      
      // Verificar se Firebase já foi inicializado
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠️ Firebase não foi inicializado. Certifique-se de chamar Firebase.initializeApp() no main.dart');
        return;
      }

      _firebaseMessaging = FirebaseMessaging.instance;

      // Solicitar permissão de notificações (iOS e Android 13+)
      final settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Permissão FCM concedida');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ Permissão FCM provisória');
      } else {
        debugPrint('❌ Permissão FCM negada');
        return;
      }

      // Configurar handlers para notificações FCM
      // Foreground: quando o app está aberto
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Background: quando o app está em background (já configurado via top-level function)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageOpened);

      // Obter token FCM
      await _getFCMToken();

      // Listener para quando o token é atualizado
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('🔄 Token FCM atualizado: $newToken');
        onFcmTokenUpdated?.call(newToken);
      });

      _fcmInitialized = true;
      debugPrint('✅ FCM inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar FCM: ${e.toString()}');
      // Continua mesmo sem FCM (notificações locais ainda funcionam)
    }
  }
  
  /// Obter token FCM atual
  static Future<String?> _getFCMToken() async {
    try {
      if (_firebaseMessaging == null) return null;
      
      _fcmToken = await _firebaseMessaging!.getToken();
      if (_fcmToken != null) {
        debugPrint('✅ Token FCM obtido: $_fcmToken');
        onFcmTokenUpdated?.call(_fcmToken!);
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('❌ Erro ao obter token FCM: ${e.toString()}');
      return null;
    }
  }
  
  /// Obter token FCM (método público)
  static Future<String?> getFCMToken() async {
    if (kIsWeb) {
      debugPrint('ℹ️ FCM not supported on web');
      return null;
    }
    if (!_fcmInitialized) {
      await _initializeFCM();
    }
    return _fcmToken ?? await _getFCMToken();
  }
  
  /// Handler para notificações FCM quando o app está em foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📨 Notificação FCM recebida (foreground): ${message.notification?.title}');
    debugPrint('📦 Payload data: ${message.data}');
    
    // Notificar o app para mostrar in-app notification
    // O callback será configurado no main.dart ou em um widget de nível superior
    onForegroundMessage?.call(message);
    
    // Também mostrar notificação local (como backup/para histórico)
    if (message.notification != null) {
      await _showLocalNotificationFromFCM(message);
    }
  }
  
  /// Handler para quando o usuário toca em uma notificação FCM com o app em background
  static void _handleBackgroundMessageOpened(RemoteMessage message) {
    debugPrint('🔔 Notificação FCM tocada (background): ${message.notification?.title}');
    debugPrint('📦 Payload: ${message.data}');
    // Aqui você pode navegar para a tela apropriada baseado no payload
  }
  
  /// Mostrar notificação local a partir de uma mensagem FCM
  static Future<void> _showLocalNotificationFromFCM(RemoteMessage message) async {
    if (!_initialized) await initialize();
    
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _medicamentoChannelId,
      _medicamentoChannelName,
      channelDescription: _medicamentoChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title ?? '💊 Caremind',
      ),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    await _notifications.show(
      message.hashCode, // ID único baseado na mensagem
      notification.title ?? '💊 Caremind',
      notification.body ?? '',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data.toString(),
    );
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
  /// Respeita a configuração de notificações do usuário.
  /// 
  /// **Exemplo de uso:**
  /// ```dart
  /// final medicamento = Medicamento(...);
  /// await NotificationService.scheduleMedicationReminders(medicamento);
  /// ```
  static Future<void> scheduleMedicationReminders(Medicamento medicamento) async {
    // Verificar se notificações de medicamentos estão habilitadas
    final settings = _getSettingsService();
    if (settings != null && !settings.notificationsMedicamentos) {
      debugPrint('ℹ️ Notificações de medicamentos desabilitadas pelo usuário');
      return;
    }

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
      debugPrint('⚠️ Erro ao parsear horário: $timeStr - ${e.toString()}');
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

/// Handler top-level para notificações FCM em background (quando o app está completamente fechado)
/// 
/// Esta função DEVE estar no nível superior do arquivo (não dentro de uma classe)
/// e DEVE ser uma função top-level ou estática para funcionar corretamente.
/// 
/// IMPORTANTE: Esta função é chamada automaticamente pelo Firebase quando uma
/// notificação chega com o app em background ou fechado.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // IMPORTANTE: Inicializar Firebase se ainda não foi inicializado
  // Isso é necessário porque esta função roda em um isolate separado
  await Firebase.initializeApp();
  
  debugPrint('📨 Notificação FCM recebida (background/terminated): ${message.notification?.title}');
  debugPrint('📦 Payload: ${message.data}');
  
  // Mostrar notificação local mesmo quando em background
  // Isso garante que o usuário veja a notificação mesmo com o app fechado
  final FlutterLocalNotificationsPlugin localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  // Inicializar timezone se necessário
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
  
  // Configurar canal Android
  const androidChannel = AndroidNotificationChannel(
    'lembrete_medicamento_channel',
    'Lembretes de Medicamentos',
    description: 'Notificações de horários de medicamentos com som e vibração',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  
  final androidImplementation = localNotifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  
  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(androidChannel);
  }
  
  // Mostrar notificação
  if (message.notification != null) {
    final notification = message.notification!;
    
    final androidDetails = AndroidNotificationDetails(
      'lembrete_medicamento_channel',
      'Lembretes de Medicamentos',
      channelDescription: 'Notificações de horários de medicamentos com som e vibração',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title ?? '💊 Caremind',
      ),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    await localNotifications.show(
      message.hashCode,
      notification.title ?? '💊 Caremind',
      notification.body ?? '',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data.toString(),
    );
  }
}
