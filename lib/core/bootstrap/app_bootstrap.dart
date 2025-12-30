import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';
import '../injection/injection.dart';
import '../../services/offline_cache_service.dart';
import '../../services/fcm_token_service.dart';
import '../../services/notificacoes_app_service.dart';
import '../../services/accessibility_service.dart';
import '../../services/daily_cache_service.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/notification_service.dart';
import '../../models/medicamento.dart';
import '../../firebase_options.dart';

class AppBootstrap {
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    await _setupOrientation();
    await _loadEnv();
    await _initOfflineCache();
    await _initFirebase();
    await _initSupabase();
    await _initDependencies();
    await _initServices();
    await _syncInitialData();
  }

  static Future<void> _setupOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  static Future<void> _loadEnv() async {
    await dotenv.load(fileName: ".env");
  }

  static Future<void> _initOfflineCache() async {
    await OfflineCacheService.initialize();
    debugPrint('✅ OfflineCacheService inicializado');
  }

  static Future<void> _initFirebase() async {
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase inicializado (FCM)');
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('⚠️ Erro ao inicializar Firebase (FCM): $e');
      }
    }
  }

  static Future<void> _initSupabase() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('Configurações do Supabase não encontradas no .env');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('✅ Supabase inicializado');
  }

  static Future<void> _initDependencies() async {
    await configureDependencies();
  }

  static Future<void> _initServices() async {
    if (!kIsWeb) {
      try {
        await GetIt.instance<FCMTokenService>().initialize();
        await GetIt.instance<NotificacoesAppService>().initialize();
      } catch (e) {
        debugPrint('⚠️ Erro ao inicializar serviços de notificação: $e');
      }
    }

    try {
      await AccessibilityService.initialize();
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar AccessibilityService: $e');
    }
  }

  static Future<void> _syncInitialData() async {
    await _syncDailyCacheIfNeeded();
    await rescheduleAllMedications();
  }

  static Future<void> _syncDailyCacheIfNeeded() async {
    try {
      final dailyCache = GetIt.instance<DailyCacheService>();
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user != null) {
        final perfil = await supabaseService.getProfile(user.id);
        if (perfil != null && dailyCache.shouldSync()) {
          await dailyCache.syncDailyData(perfil.id);
          debugPrint('✅ Cache diário sincronizado');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao sincronizar cache diário: $e');
    }
  }

  static Future<void> rescheduleAllMedications() async {
    try {
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user == null) return;

      final medicamentoService = MedicamentoService(supabaseService.client);
      final medicamentosResult = await medicamentoService.getMedicamentos(user.id);

      final medicamentos = medicamentosResult.when(
        success: (data) => data,
        failure: (_) => <Medicamento>[],
      );

      for (final medicamento in medicamentos) {
        await NotificationService.scheduleMedicationReminders(medicamento);
      }
      debugPrint('✅ Notificações de medicamentos re-agendadas');
    } catch (e) {
      debugPrint('❌ Erro crítico ao re-agendar medicamentos: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}
