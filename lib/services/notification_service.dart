import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import '../models/medicamento.dart';
import 'settings_service.dart';
import '../core/injection/injection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vinculo_familiar.dart';

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

  // Callbacks para notificar erros FCM ao usuário
  static Function(String message)? onFcmPermissionDenied;
  static Function(String message)? onFcmTokenError;
  static Function(String message)? onFcmInitializationError;

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

  // Constantes para Snooze e Escalonamento
  static const int _snoozeMinutes = 5;
  static const int _maxSnoozes = 2; // Máximo 2 snoozes (total 3 tentativas)
  static const String _snoozeStateKey = 'medication_snooze_state';

  /// Inicializar o serviço de notificações (Locais + FCM)
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Inicializar timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

      // Configurações Android - CRÍTICO para som e vibração
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

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
        onDidReceiveBackgroundNotificationResponse: notificationActionHandler,
      );

      if (initialized != true) {
        debugPrint(
            '⚠️ NotificationService: Falha ao inicializar notificações locais');
        return;
      }

      // Criar canal Android com importance.max para som e vibração fortes
      await _createMedicamentoChannel();

      // Solicitar permissões
      await requestPermissions();

      // Verificar permissões de alarmes exatos (Android 13+)
      await checkAndRequestExactAlarmPermission();

      // Configurar bypass de DND (já está no canal)
      await requestDndBypassPermission();

      // Inicializar Firebase Messaging (Push Notifications Remotas)
      await _initializeFCM();

      _initialized = true;
      debugPrint(
          '✅ NotificationService: Inicializado com sucesso (Local + FCM)');
    } catch (e) {
      debugPrint(
          '❌ NotificationService: Erro ao inicializar - ${e.toString()}');
      _initialized = true; // Continua mesmo com erro
    }
  }

  /// Inicializar Firebase Cloud Messaging (FCM) para Push Notifications Remotas
  static Future<void> _initializeFCM() async {
    try {
      // FCM não funciona na web
      if (kIsWeb) {
        debugPrint(
            'ℹ️ FCM não suportado na web. Apenas notificações locais serão usadas.');
        return;
      }

      // Verificar se Firebase já foi inicializado
      if (Firebase.apps.isEmpty) {
        debugPrint(
            '⚠️ Firebase não foi inicializado. Certifique-se de chamar Firebase.initializeApp() no main.dart');
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
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ Permissão FCM provisória');
        onFcmPermissionDenied?.call(
          'Permissão de notificações provisória. Você pode não receber todos os alertas de medicamento.',
        );
      } else {
        debugPrint('❌ Permissão FCM negada');
        onFcmPermissionDenied?.call(
          'Permissão de notificações negada. Você não receberá alertas de medicamento. Ative nas configurações do dispositivo.',
        );
        return;
      }

      // Configurar handlers para notificações FCM
      // Foreground: quando o app está aberto
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background: quando o app está em background (já configurado via top-level function)
      FirebaseMessaging.onMessageOpenedApp
          .listen(_handleBackgroundMessageOpened);

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
      onFcmInitializationError?.call(
        'Erro ao configurar notificações push. Você pode não receber alertas de medicamento. Notificações locais continuam funcionando.',
      );
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
      onFcmTokenError?.call(
        'Erro ao obter token de notificações. Você pode não receber alertas de medicamento. Tente reiniciar o app.',
      );
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
    debugPrint(
        '📨 Notificação FCM recebida (foreground): ${message.notification?.title}');
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
    debugPrint(
        '🔔 Notificação FCM tocada (background): ${message.notification?.title}');
    debugPrint('📦 Payload: ${message.data}');
    // Aqui você pode navegar para a tela apropriada baseado no payload
  }

  /// Mostrar notificação local a partir de uma mensagem FCM
  static Future<void> _showLocalNotificationFromFCM(
      RemoteMessage message) async {
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
      bypassDnd: true, // CRÍTICO: Bypass do modo Não Perturbe
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

  /// Verificar e solicitar permissão USE_EXACT_ALARM (Android 13+)
  ///
  /// Android 13+ (API 33+) requer permissão explícita para usar alarmes exatos.
  /// Retorna true se a permissão está disponível, false caso contrário.
  static Future<bool> checkAndRequestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android == null) return false;

      // Verificar se pode agendar alarmes exatos
      final canSchedule = await android.canScheduleExactNotifications();

      if (canSchedule == true) {
        debugPrint('✅ Permissão USE_EXACT_ALARM: Já disponível');
        return true;
      }

      debugPrint(
          '⚠️ Permissão USE_EXACT_ALARM: Não disponível. Solicitando...');

      // Tentar solicitar permissão (pode abrir configurações do sistema)
      final requested = await android.requestExactAlarmsPermission();

      if (requested == true) {
        debugPrint('✅ Permissão USE_EXACT_ALARM: Concedida');
        return true;
      } else {
        debugPrint(
            '❌ Permissão USE_EXACT_ALARM: Negada. Usuário precisa habilitar manualmente.');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar USE_EXACT_ALARM: $e');
      // Em caso de erro, continuar (pode funcionar mesmo sem a permissão em alguns casos)
      return false;
    }
  }

  /// Verificar se pode agendar alarmes exatos (método público)
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return false;

    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Verificar se otimização de bateria está desabilitada (método público)
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;

    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (e) {
      debugPrint('❌ Erro ao verificar otimização de bateria: $e');
      return false;
    }
  }

  /// Solicitar desabilitar otimização de bateria (método público)
  static Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Erro ao solicitar desabilitar otimização: $e');
      return false;
    }
  }

  /// Solicitar permissão de bypass do modo Não Perturbe (DND) no Android
  ///
  /// Esta permissão é crítica para garantir que notificações de medicamentos
  /// sejam exibidas mesmo quando o dispositivo está em modo Não Perturbe.
  ///
  /// Android 6.0+ (API 23+): O bypass de DND é configurado através do canal
  /// de notificação com `bypassDnd: true` (já implementado em _createMedicamentoChannel).
  ///
  /// Nota: A permissão ACCESS_NOTIFICATION_POLICY pode ser necessária em alguns
  /// dispositivos, mas não está disponível via permission_handler. O usuário pode
  /// precisar habilitar manualmente nas configurações do sistema.
  static Future<bool> requestDndBypassPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      // O bypass de DND é configurado através do canal de notificação
      // com bypassDnd: true, que já foi implementado em _createMedicamentoChannel()
      //
      // Para dispositivos que requerem permissão adicional, o usuário precisará
      // habilitar manualmente nas configurações do sistema:
      // Configurações > Apps > CareMind > Notificações > Permitir interromper modo Não Perturbe

      debugPrint(
          'ℹ️ Bypass DND: Configurado através do canal de notificação (bypassDnd: true)');
      debugPrint(
          'ℹ️ Se necessário, habilite manualmente nas configurações do sistema');

      // Retornar true pois o canal já está configurado corretamente
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao verificar configuração DND bypass: $e');
      // Continuar mesmo com erro - notificações ainda podem funcionar
      return false;
    }
  }

  /// Verificar se a permissão de bypass DND está concedida (método público)
  ///
  /// Nota: A verificação real do status de bypass DND requer acesso nativo
  /// que não está disponível via flutter_local_notifications. Este método
  /// verifica se o canal foi criado corretamente (com bypassDnd: true).
  ///
  /// Para uma verificação mais precisa, seria necessário usar código nativo Android.
  static Future<bool> isDndBypassGranted() async {
    if (!Platform.isAndroid) return true;

    try {
      // O canal foi criado com bypassDnd: true em _createMedicamentoChannel()
      // A verificação real se o usuário permitiu nas configurações requer
      // acesso nativo que não está disponível via flutter_local_notifications

      // Por enquanto, assumimos que se o canal foi criado, está configurado
      // O usuário pode precisar habilitar manualmente nas configurações
      // se o dispositivo requerer permissão adicional

      debugPrint('ℹ️ Bypass DND: Canal configurado com bypassDnd: true');
      debugPrint('ℹ️ Verificação real requer acesso nativo (não disponível)');

      // Como não podemos verificar o status real via API, vamos sempre
      // mostrar o dialog na primeira vez para garantir que o usuário saiba
      // como habilitar se necessário
      return false;
    } catch (e) {
      debugPrint('❌ Erro ao verificar permissão DND bypass: $e');
      return false;
    }
  }

  /// Abrir configurações de notificação do app no Android
  ///
  /// Abre diretamente a tela de configurações de notificação do CareMind
  /// onde o usuário pode habilitar o bypass de DND.
  static Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;

    try {
      // Abrir configurações do app (vai para a tela de notificações)
      await openAppSettings();
      debugPrint('✅ Abrindo configurações de notificação do app');
    } catch (e) {
      debugPrint('❌ Erro ao abrir configurações: $e');
    }
  }

  /// Mostrar dialog informando sobre bypass de DND
  ///
  /// Exibe um dialog explicando a importância do bypass de DND e oferece
  /// um botão para abrir as configurações do sistema.
  static Future<void> showDndBypassDialog(BuildContext context) async {
    if (!Platform.isAndroid) return;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.notifications_active,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Modo Não Perturbe',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para garantir que você receba todos os alertas de medicamentos, mesmo quando o dispositivo estiver em modo Não Perturbe, é necessário habilitar esta permissão.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta configuração é importante para sua saúde!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Como habilitar:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildInstructionItem('1. Toque em "Abrir Configurações" abaixo'),
              _buildInstructionItem(
                  '2. Procure por "Notificações" ou "Notifications"'),
              _buildInstructionItem('3. Encontre "Lembretes de Medicamentos"'),
              _buildInstructionItem(
                  '4. Ative "Permitir interromper modo Não Perturbe"'),
              _buildInstructionItem('5. Volte ao app'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Depois'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              openNotificationSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Abrir Configurações'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget helper para itens de instrução
  static Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Verificar e solicitar bypass de DND com dialog se necessário
  ///
  /// Verifica se o bypass está ativo e mostra um dialog se não estiver.
  /// Retorna true se está ativo ou foi configurado, false caso contrário.
  static Future<bool> checkAndRequestDndBypass(BuildContext? context) async {
    if (!Platform.isAndroid) return true;
    if (context == null) return false;

    try {
      // Verificar se está ativo
      final isGranted = await isDndBypassGranted();

      if (isGranted) {
        debugPrint('✅ Bypass DND: Já está ativo');
        return true;
      }

      // Mostrar dialog para o usuário
      await showDndBypassDialog(context);

      // Verificar novamente após o usuário voltar
      return await isDndBypassGranted();
    } catch (e) {
      debugPrint('❌ Erro ao verificar bypass DND: $e');
      return false;
    }
  }

  /// Handler quando usuário toca na notificação (foreground)
  static void _onNotificationTapped(NotificationResponse response) async {
    debugPrint(
        '🔔 Notificação tocada - ID: ${response.id}, Payload: ${response.payload}, Action: ${response.actionId}');

    await _handleNotificationAction(response);
  }

  /// Processar ação da notificação (snooze ou confirmar)
  static Future<void> _handleNotificationAction(
      NotificationResponse response) async {
    try {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) {
        debugPrint('⚠️ Notificação sem payload: ${response.id}');
        return;
      }

      final medicamentoId = int.tryParse(payload);
      if (medicamentoId == null) {
        debugPrint('⚠️ Payload inválido para medicamento: $payload');
        return;
      }

      // Se ação for "snooze", agendar snooze
      if (response.actionId == 'snooze') {
        try {
          await scheduleSnooze(medicamentoId);
        } catch (e) {
          debugPrint('❌ Erro ao agendar snooze: $e');
          // Não relançar erro - já foi logado
        }
      }
      // Se ação for "confirm", marcar como confirmado (cancelar notificações pendentes)
      else if (response.actionId == 'confirm') {
        try {
          await confirmMedication(medicamentoId);
        } catch (e) {
          debugPrint('❌ Erro ao confirmar medicamento: $e');
          // Não relançar erro - já foi logado
        }
      }
      // Se apenas tocou na notificação (sem ação), navegar para tela do medicamento
      else {
        try {
          // Chamar callback para navegação (será configurado no main.dart)
          onNotificationTapped?.call(medicamentoId);
        } catch (e) {
          debugPrint('❌ Erro ao chamar callback de navegação: $e');
          // Não relançar erro - callback pode não estar configurado
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao processar ação de notificação: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Callback para quando uma notificação é tocada (para navegação)
  static Function(int medicamentoId)? onNotificationTapped;

  /// Processar ação da notificação em background (método estático para ser chamado pela função top-level)
  static Future<void> _handleNotificationActionInBackground(
      NotificationResponse response) async {
    try {
      // Garantir que timezone está inicializado (pode não estar em background)
      try {
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (e) {
        // Timezone já inicializado ou erro (continuar mesmo assim)
        debugPrint('ℹ️ Timezone já inicializado ou erro: $e');
      }

      // Garantir que serviço está inicializado
      if (!_initialized) {
        try {
          await initialize();
        } catch (e) {
          debugPrint('❌ Erro ao inicializar serviço em background: $e');
          // Tentar continuar mesmo sem inicialização completa
        }
      }

      await _handleNotificationAction(response);
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao processar ação de notificação em background: $e');
      debugPrint('Stack trace: $stackTrace');
      // Não relançar - erro já foi logado
    }
  }

  /// Agendar Snooze (repetir notificação após 5 minutos)
  static Future<void> scheduleSnooze(int medicamentoId) async {
    try {
      if (!_initialized) {
        try {
          await initialize();
        } catch (e) {
          debugPrint('❌ Erro ao inicializar serviço para snooze: $e');
          return;
        }
      }

      // Obter estado atual de snooze
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint('❌ Erro ao obter SharedPreferences para snooze: $e');
        return;
      }

      final stateKey = '${_snoozeStateKey}_$medicamentoId';
      final snoozeCount = prefs.getInt(stateKey) ?? 0;

      if (snoozeCount >= _maxSnoozes) {
        // Máximo de snoozes atingido - escalar para familiar
        debugPrint(
            '⚠️ Máximo de snoozes atingido para medicamento $medicamentoId. Escalando para familiar...');
        try {
          await _escalateToFamiliar(medicamentoId);
        } catch (e) {
          debugPrint('❌ Erro ao escalar para familiar: $e');
          // Continuar mesmo com erro no escalonamento
        }
        // Limpar estado de snooze
        try {
          await prefs.remove(stateKey);
        } catch (e) {
          debugPrint('⚠️ Erro ao limpar estado de snooze: $e');
        }
        return;
      }

      // Incrementar contador de snooze ANTES de usar
      final newSnoozeCount = snoozeCount + 1;
      try {
        await prefs.setInt(stateKey, newSnoozeCount);
      } catch (e) {
        debugPrint('❌ Erro ao salvar estado de snooze: $e');
        return;
      }

      // Buscar medicamento para obter informações
      final medicamento = await _getMedicamentoById(medicamentoId);
      if (medicamento == null) {
        debugPrint('⚠️ Medicamento $medicamentoId não encontrado para snooze');
        // Reverter contador de snooze
        try {
          await prefs.setInt(stateKey, snoozeCount);
        } catch (e) {
          debugPrint('⚠️ Erro ao reverter contador de snooze: $e');
        }
        return;
      }

      // Calcular horário do snooze (5 minutos a partir de agora)
      DateTime snoozeTime;
      tz.TZDateTime tzSnoozeTime;
      try {
        snoozeTime =
            DateTime.now().add(const Duration(minutes: _snoozeMinutes));
        tzSnoozeTime = tz.TZDateTime.from(snoozeTime, tz.local);
      } catch (e) {
        debugPrint('❌ Erro ao calcular horário do snooze: $e');
        // Reverter contador de snooze
        try {
          await prefs.setInt(stateKey, snoozeCount);
        } catch (e2) {
          debugPrint('⚠️ Erro ao reverter contador de snooze: $e2');
        }
        return;
      }

      // Gerar ID único para snooze (usar ID negativo para diferenciar)
      // Usar newSnoozeCount para garantir ID único
      final snoozeId = -(medicamentoId * 1000 + newSnoozeCount);

      final saudacao = _getSaudacao(snoozeTime.hour);
      final titulo = '$saudacao Lembrete: ${medicamento.nome}';
      final corpo =
          '⏰ Você ainda não confirmou este medicamento. ${_getCorpoNotificacao(medicamento, TimeOfDay(hour: snoozeTime.hour, minute: snoozeTime.minute))}';

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
          corpo,
          contentTitle: titulo,
          summaryText: 'CareMind - Lembrete de Medicamento',
        ),
        ongoing: false,
        autoCancel: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        ticker: 'Lembrete: ${medicamento.nome}',
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze',
            'Soneca (5 min)',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'confirm',
            'Tomado',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.critical,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      try {
        await _notifications.zonedSchedule(
          snoozeId,
          titulo,
          corpo,
          tzSnoozeTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: medicamentoId.toString(),
        );

        debugPrint(
            '✅ Snooze agendado: Medicamento=$medicamentoId, Tentativa=$newSnoozeCount/${_maxSnoozes + 1}, Horário=$snoozeTime');
      } catch (e) {
        debugPrint('❌ Erro ao agendar notificação de snooze: $e');
        // Reverter contador de snooze em caso de erro
        try {
          await prefs.setInt(stateKey, snoozeCount);
        } catch (e2) {
          debugPrint('⚠️ Erro ao reverter contador de snooze após falha: $e2');
        }
        rethrow; // Relançar para ser capturado pelo catch externo
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao agendar snooze: $e');
      debugPrint('Stack trace: $stackTrace');
      // Não relançar - erro já foi logado e tratado
    }
  }

  /// Confirmar medicamento (cancelar notificações pendentes e limpar snooze)
  /// Método público para ser chamado quando o usuário confirma o medicamento
  static Future<void> confirmMedication(int medicamentoId) async {
    try {
      // Cancelar todas as notificações deste medicamento
      try {
        await _cancelMedicamentoNotifications(medicamentoId);
      } catch (e) {
        debugPrint('⚠️ Erro ao cancelar notificações do medicamento: $e');
        // Continuar mesmo com erro
      }

      // Cancelar snoozes pendentes (IDs negativos)
      for (int i = 0; i <= _maxSnoozes; i++) {
        try {
          final snoozeId = -(medicamentoId * 1000 + i);
          await _notifications.cancel(snoozeId);
        } catch (e) {
          debugPrint('⚠️ Erro ao cancelar snooze $i: $e');
          // Continuar cancelando os outros
        }
      }

      // Limpar estado de snooze
      try {
        final prefs = await SharedPreferences.getInstance();
        final stateKey = '${_snoozeStateKey}_$medicamentoId';
        await prefs.remove(stateKey);
      } catch (e) {
        debugPrint('⚠️ Erro ao limpar estado de snooze: $e');
        // Continuar mesmo com erro
      }

      debugPrint(
          '✅ Medicamento $medicamentoId confirmado. Notificações canceladas.');
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao confirmar medicamento: $e');
      debugPrint('Stack trace: $stackTrace');
      // Não relançar - erro já foi logado
    }
  }

  /// Escalar para familiar (após 3 tentativas sem confirmação)
  static Future<void> _escalateToFamiliar(int medicamentoId) async {
    try {
      final medicamento = await _getMedicamentoById(medicamentoId);
      if (medicamento == null) {
        debugPrint(
            '⚠️ Medicamento $medicamentoId não encontrado para escalonamento');
        return;
      }

      // Buscar vínculos familiares do idoso
      final vinculos = await _getVinculosFamiliares(medicamento.perfilId);

      if (vinculos.isEmpty) {
        debugPrint(
            '⚠️ Nenhum familiar vinculado para medicamento $medicamentoId');
        return;
      }

      // Buscar perfil do idoso para obter nome
      final idosoNome = await _getNomePerfil(medicamento.perfilId);

      // Enviar notificação para cada familiar via Edge Function
      int sucessos = 0;
      int falhas = 0;

      for (final vinculo in vinculos) {
        try {
          await _sendPushToFamiliar(
            familiarId: vinculo.idFamiliar,
            medicamentoId: medicamentoId,
            medicamentoNome: medicamento.nome,
            idosoNome: idosoNome ?? 'Idoso',
          );
          sucessos++;
        } catch (e) {
          falhas++;
          debugPrint(
              '⚠️ Erro ao enviar push para familiar ${vinculo.idFamiliar}: $e');
          // Continuar enviando para os outros familiares
        }
      }

      if (sucessos > 0) {
        debugPrint(
            '✅ Escalonamento enviado: $sucessos sucesso(s), $falhas falha(s) de ${vinculos.length} familiar(es)');
      } else {
        debugPrint('❌ Falha ao enviar escalonamento para todos os familiares');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao escalar para familiar: $e');
      debugPrint('Stack trace: $stackTrace');
      // Não relançar - erro já foi logado
    }
  }

  /// Buscar medicamento por ID (helper)
  static Future<Medicamento?> _getMedicamentoById(int medicamentoId) async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('medicamentos')
          .select()
          .eq('id', medicamentoId)
          .maybeSingle();

      if (response == null) return null;
      return Medicamento.fromMap(response);
    } catch (e) {
      debugPrint('❌ Erro ao buscar medicamento: $e');
      return null;
    }
  }

  /// Buscar vínculos familiares (helper)
  static Future<List<VinculoFamiliar>> _getVinculosFamiliares(
      String idosoId) async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('vinculos_familiares')
          .select()
          .eq('id_idoso', idosoId);

      return (response as List)
          .map((data) => VinculoFamiliar.fromMap(data))
          .toList();
    } catch (e) {
      debugPrint('❌ Erro ao buscar vínculos familiares: $e');
      return [];
    }
  }

  /// Obter nome do perfil (helper)
  static Future<String?> _getNomePerfil(String perfilId) async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('perfis')
          .select('nome')
          .eq('id', perfilId)
          .maybeSingle();

      return response?['nome'] as String?;
    } catch (e) {
      debugPrint('❌ Erro ao buscar nome do perfil: $e');
      return null;
    }
  }

  /// Enviar push notification para familiar via Edge Function
  static Future<void> _sendPushToFamiliar({
    required String familiarId,
    required int medicamentoId,
    required String medicamentoNome,
    required String idosoNome,
  }) async {
    try {
      final client = Supabase.instance.client;

      // Chamar Edge Function para enviar push
      final response = await client.functions.invoke(
        'enviar-push-notification',
        body: {
          'userId': familiarId,
          'title': '⚠️ Alerta: Medicamento não confirmado',
          'body':
              '$idosoNome não confirmou o medicamento "$medicamentoNome". Por favor, verifique.',
          'data': {
            'type': 'medication_escalation',
            'medicamento_id': medicamentoId.toString(),
            'idoso_nome': idosoNome,
            'medicamento_nome': medicamentoNome,
          },
          'priority': 'high',
        },
      );

      if (response.status == 200) {
        debugPrint('✅ Push enviado para familiar $familiarId');
      } else {
        debugPrint(
            '⚠️ Push enviado para familiar $familiarId com status: ${response.status}');
        final errorData = response.data;
        if (errorData != null &&
            errorData is Map &&
            errorData.containsKey('error')) {
          throw Exception('Erro na Edge Function: ${errorData['error']}');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao enviar push para familiar $familiarId: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow; // Relançar para ser tratado pelo chamador
    }
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
  static Future<void> scheduleMedicationReminders(
      Medicamento medicamento) async {
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
      debugPrint(
          '⚠️ Medicamento ${medicamento.nome}: Nenhum horário encontrado');
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

    debugPrint(
        '✅ ${horarios.length} notificação(ões) agendada(s) para ${medicamento.nome}');
  }

  /// Extrair horários da frequência do medicamento
  ///
  /// Suporta diferentes formatos:
  /// - Frequência diária com horários: `{tipo: 'diario', horarios: ['08:00', '20:00']}`
  /// - Frequência diária com vezes_por_dia: `{tipo: 'diario', vezes_por_dia: 2}` (gera horários padrão)
  /// - Outros formatos serão adaptados conforme necessário
  static List<TimeOfDay> _extractHorarios(Medicamento medicamento) {
    final frequencia = medicamento.frequencia;

    if (frequencia == null) {
      return _generateDefaultHorarios(2);
    }

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
      const TimeOfDay(hour: 8, minute: 0), // 08:00 - Manhã
      const TimeOfDay(hour: 14, minute: 0), // 14:00 - Tarde
      const TimeOfDay(hour: 20, minute: 0), // 20:00 - Noite
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
      final titulo = '$saudacao Hora do ${medicamento.nome}!';
      final corpo = _getCorpoNotificacao(medicamento, horario);

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
          corpo,
          contentTitle: titulo,
          summaryText: 'CareMind cuida de você',
        ),
        ongoing: false,
        autoCancel: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        ticker: 'Hora do medicamento: ${medicamento.nome}',
        // Ações para Snooze e Confirmar
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze',
            'Soneca (5 min)',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'confirm',
            'Tomado',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.critical,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        titulo,
        corpo,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: medicamento.id.toString(),
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

  static String _getSaudacao(int hora) {
    if (hora >= 5 && hora < 12) {
      return '🌅 Bom dia!';
    } else if (hora >= 12 && hora < 18) {
      return '☀️ Boa tarde!';
    } else {
      return '🌙 Boa noite!';
    }
  }

  static String _getCorpoNotificacao(
      Medicamento medicamento, TimeOfDay horario) {
    final nomeFormatado = medicamento.nome;
    final dosagem = medicamento.dosagem ?? 'sua dose';
    final via = medicamento.via ?? 'oral';

    final mensagens = [
      'Tome $dosagem de $nomeFormatado agora. Sua saúde agradece! 💪',
      '$nomeFormatado $dosagem - via $via. Cuide-se bem! 🌟',
      'Não esqueça: $dosagem de $nomeFormatado. Você está cuidando de você! ❤️',
      'Hora de tomar $nomeFormatado ($dosagem). Continue firme! 💊',
    ];

    final index = horario.hour % mensagens.length;
    var corpo = mensagens[index];

    if (medicamento.quantidade != null && medicamento.quantidade! <= 5) {
      corpo +=
          '\n\n⚠️ Atenção: Restam apenas ${medicamento.quantidade} unidade(s). Reponha seu estoque!';
    }

    return corpo;
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

    debugPrint(
        '🗑️ Notificações canceladas para medicamento ID=$medicamentoId');
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

  debugPrint(
      '📨 Notificação FCM recebida (background/terminated): ${message.notification?.title}');
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

  final androidImplementation =
      localNotifications.resolvePlatformSpecificImplementation<
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
      channelDescription:
          'Notificações de horários de medicamentos com som e vibração',
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

/// Handler top-level para ações de notificações locais em background
///
/// Esta função DEVE estar no nível superior do arquivo (não dentro de uma classe)
/// para funcionar corretamente quando o app está em background ou fechado.
///
/// IMPORTANTE: Esta função não pode ser async, mas pode chamar métodos assíncronos.
/// O método assíncrono será executado em background.
@pragma('vm:entry-point')
void notificationActionHandler(NotificationResponse response) {
  debugPrint(
      '🔔 Notificação tocada (background) - ID: ${response.id}, Payload: ${response.payload}, Action: ${response.actionId}');

  // Processar ação em background de forma assíncrona
  // Usar unawaited para não bloquear, mas processar em background
  NotificationService._handleNotificationActionInBackground(response)
      .catchError((error) {
    debugPrint('❌ Erro ao processar ação de notificação em background: $error');
  });
}
