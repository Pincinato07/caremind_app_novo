import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_shell.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/individual/dashboard_screen.dart';
import 'screens/familiar/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/shared/configuracoes_screen.dart';
import 'screens/shared/perfil_screen.dart';
import 'screens/medication/gestao_medicamentos_screen.dart';
import 'screens/rotinas/gestao_rotinas_screen.dart';
import 'screens/compromissos/gestao_compromissos_screen.dart';
import 'screens/integracoes/integracoes_screen.dart';
import 'screens/shared/alertas_screen.dart';
import 'widgets/global_wave_background.dart';
import 'widgets/accessibility_wrapper.dart';
import 'widgets/in_app_notification.dart';
import 'core/injection/injection.dart';
import 'services/notification_service.dart';
import 'services/fcm_token_service.dart';
import 'services/notificacoes_app_service.dart';
import 'services/accessibility_service.dart';
import 'services/daily_cache_service.dart';
import 'services/supabase_service.dart';
import 'services/offline_cache_service.dart';
import 'package:get_it/get_it.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");

  // Inicializar cache offline
  await OfflineCacheService.initialize();
  debugPrint('✅ OfflineCacheService inicializado');

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase inicializado (FCM)');
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      debugPrint('✅ Handler de background FCM configurado');
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar Firebase (FCM): $e');
    }
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception('SUPABASE_URL não encontrado');
  }
  
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('SUPABASE_ANON_KEY não encontrado');
  }
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  debugPrint('✅ Supabase inicializado');

  await configureDependencies();
  
  if (!kIsWeb) {
    try {
      final fcmTokenService = GetIt.instance<FCMTokenService>();
      await fcmTokenService.initialize();
      debugPrint('✅ FCMTokenService inicializado');
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar FCMTokenService: $e');
    }
  }
  
  if (!kIsWeb) {
    try {
      final notificacoesService = GetIt.instance<NotificacoesAppService>();
      await notificacoesService.initialize();
      debugPrint('✅ NotificacoesAppService inicializado');
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar NotificacoesAppService: $e');
    }
  }
  
  try {
    await AccessibilityService.initialize();
    debugPrint('✅ AccessibilityService inicializado');
  } catch (e) {
    debugPrint('⚠️ Erro ao inicializar AccessibilityService: $e');
  }

  await _syncDailyCacheIfNeeded();
  
  runApp(const CareMindApp());
}

Future<void> _syncDailyCacheIfNeeded() async {
  try {
    final dailyCache = GetIt.instance<DailyCacheService>();
    final supabaseService = GetIt.instance<SupabaseService>();
    final user = supabaseService.currentUser;
    
    if (user != null) {
      final perfil = await supabaseService.getProfile(user.id);
      if (perfil != null && dailyCache.shouldSync()) {
        await dailyCache.syncDailyData(perfil.id);
        debugPrint('✅ Cache diário sincronizado para ${perfil.nome}');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Erro ao sincronizar cache diário: $e');
  }
}

class CareMindApp extends StatefulWidget {
  const CareMindApp({super.key});

  @override
  State<CareMindApp> createState() => _CareMindAppState();
}

class _CareMindAppState extends State<CareMindApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFCMForegroundHandler();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncDailyCacheOnResume();
    }
  }

  Future<void> _syncDailyCacheOnResume() async {
    try {
      final dailyCache = GetIt.instance<DailyCacheService>();
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user != null && dailyCache.shouldSync()) {
        final perfil = await supabaseService.getProfile(user.id);
        if (perfil != null) {
          await dailyCache.syncDailyData(perfil.id);
          debugPrint('✅ Cache sincronizado ao retomar app');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao sincronizar cache: $e');
    }
  }

  void _setupFCMForegroundHandler() {
    if (kIsWeb) return;
    
    NotificationService.onForegroundMessage = (RemoteMessage message) {
      debugPrint('🔔 FCM recebida: ${message.notification?.title}');
      _showInAppNotification(message);
      _refreshNotifications();
    };
  }

  void _showInAppNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    String tipo = 'info';
    if (message.data.containsKey('type')) {
      final type = message.data['type'] as String?;
      if (type != null) {
        if (type.contains('medicamento')) {
          tipo = 'medicamento';
        } else if (type.contains('rotina')) {
          tipo = 'rotina';
        } else if (type.contains('compromisso')) {
          tipo = 'compromisso';
        } else if (type.contains('atrasado') || type.contains('nao_')) {
          tipo = 'warning';
        }
      }
    }

    final context = _navigatorKey.currentContext;
    if (context != null) {
      InAppNotification.show(
        context,
        titulo: notification.title ?? '💊 CareMind',
        mensagem: notification.body ?? '',
        tipo: tipo,
        onTap: () {
          _navigatorKey.currentState?.pushNamed('/alertas');
        },
      );
    }
  }

  void _refreshNotifications() {
    try {
      final service = GetIt.instance<NotificacoesAppService>();
      service.atualizarContagem();
      service.carregarNotificacoes();
    } catch (e) {
      debugPrint('Erro ao atualizar notificações: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccessibilityWrapper(
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'CareMind',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        builder: (context, child) {
          return Stack(
            children: [
              const GlobalWaveBackground(),
              child!,
            ],
          );
        },
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/': (context) => const AuthShell(initialMode: AuthMode.login),
          '/onboarding': (context) => const OnboardingScreen(),
          '/login': (context) => const AuthShell(initialMode: AuthMode.login),
          '/register': (context) => const AuthShell(initialMode: AuthMode.register),
          '/individual-dashboard': (context) => const IndividualDashboardScreen(),
          '/familiar-dashboard': (context) => const FamiliarDashboardScreen(),
          '/configuracoes': (context) => const ConfiguracoesScreen(),
          '/perfil': (context) => const PerfilScreen(),
          '/gestao-medicamentos': (context) => const GestaoMedicamentosScreen(),
          '/gestao-rotinas': (context) => const GestaoRotinasScreen(),
          '/gestao-compromissos': (context) => const GestaoCompromissosScreen(),
          '/integracoes': (context) => const IntegracoesScreen(),
          '/alertas': (context) => const AlertasScreen(),
        },
      ),
    );
  }
}
