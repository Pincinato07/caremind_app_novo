import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'screens/auth/processar_convite_screen.dart';

import 'widgets/global_wave_background.dart';
import 'widgets/accessibility_wrapper.dart';
import 'widgets/in_app_notification.dart';

import 'services/notification_service.dart';
import 'services/notificacoes_app_service.dart';
import 'services/supabase_service.dart';
import 'services/fcm_token_service.dart';
import 'services/daily_cache_service.dart';
import 'services/accessibility_service.dart';

import 'core/deep_link/deep_link_handler.dart';
import 'core/feedback/feedback_service.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/navigation/app_router.dart';

class CareMindApp extends StatefulWidget {
  const CareMindApp({super.key});

  @override
  State<CareMindApp> createState() => _CareMindAppState();

  static void changeThemeMode(ThemeMode mode) {
    _CareMindAppState.setThemeMode(mode);
  }

  static Future<void> checkDndBypassOnLogin(BuildContext? context) async {
    if (context == null || !context.mounted) return;

    try {
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final hasShownDndDialog = prefs.getBool('has_shown_dnd_dialog') ?? false;

      if (!hasShownDndDialog && context.mounted) {
        final isGranted = await NotificationService.isDndBypassGranted();
        if (!isGranted && context.mounted) {
          await NotificationService.showDndBypassDialog(context);
          await prefs.setBool('has_shown_dnd_dialog', true);
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar DND bypass no login: $e');
    }
  }
}

class _CareMindAppState extends State<CareMindApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late DeepLinkHandler _deepLinkHandler;
  ThemeMode _themeMode = ThemeMode.system;
  static final ValueNotifier<ThemeMode> _themeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFCMForegroundHandler();
    _setupFCMErrorHandlers();
    _setupAuthStateListener();
    _setupDeepLinks();
    _loadThemeMode();
    _checkDndBypassAfterInit();
  }

  void _checkDndBypassAfterInit() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user == null) return;

      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final prefs = await SharedPreferences.getInstance();
        final hasShownDndDialog = prefs.getBool('has_shown_dnd_dialog') ?? false;

        if (!hasShownDndDialog) {
          final isGranted = await NotificationService.isDndBypassGranted();
          if (!isGranted && context.mounted) {
            await NotificationService.showDndBypassDialog(context);
            await prefs.setBool('has_shown_dnd_dialog', true);
          }
        }
      }
    });
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString('theme_mode') ?? 'system';
      final loadedMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == 'ThemeMode.$themeModeString',
        orElse: () => ThemeMode.system,
      );
      setState(() {
        _themeMode = loadedMode;
      });
      _themeNotifier.value = loadedMode;
    } catch (e) {
      debugPrint('Erro ao carregar tema: $e');
    }
  }

  static void setThemeMode(ThemeMode mode) {
    _themeNotifier.value = mode;
    _saveThemeMode(mode);
  }

  static Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.toString().split('.').last);
    } catch (e) {
      debugPrint('Erro ao salvar tema: $e');
    }
  }

  void _setupDeepLinks() {
    _deepLinkHandler = DeepLinkHandler();
    if (_deepLinkHandler.initialLink != null) {
      _processDeepLink(_deepLinkHandler.initialLink!);
    }
    _deepLinkHandler.linkStream.listen((uri) {
      _processDeepLink(uri);
    });
  }

  void _processDeepLink(Uri uri) {
    try {
      debugPrint('🔗 DeepLink: Processando URI - $uri');
      
      if (DeepLinkHandler.isConviteLink(uri)) {
        final token = DeepLinkHandler.extractConviteToken(uri);
        final codigo = DeepLinkHandler.extractConviteCodigo(uri);

        if (token != null || codigo != null) {
          final tokenOuCodigo = token ?? codigo ?? '';
          final context = _navigatorKey.currentContext;
          if (context != null && context.mounted) {
            final currentRoute = ModalRoute.of(context)?.settings.name;
            if (currentRoute != '/processar-convite') {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/processar-convite'),
                  builder: (_) => ProcessarConviteScreen(
                    tokenOuCodigo: tokenOuCodigo,
                  ),
                ),
                (route) => route.isFirst,
              );
            }
          }
        }
        return;
      }

      final route = DeepLinkHandler.parseRoute(uri);
      if (route == DeepLinkRoute.medicamento) {
        final medicamentoId = DeepLinkHandler.extractMedicamentoId(uri);
        if (medicamentoId != null && medicamentoId > 0) {
          _navigateToMedication(medicamentoId);
        }
      }
    } catch (e) {
      debugPrint('❌ DeepLink: Erro - $e');
    }
  }

  void _navigateToMedication(int medicamentoId) {
    final context = _navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/individual-dashboard',
        (route) => false,
        arguments: {'highlightMedicationId': medicamentoId},
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkHandler.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncDailyCacheOnResume();
      _checkSessionOnResume();
      AppBootstrap.rescheduleAllMedications();
      _checkDndBypassOnResume();
    }
  }

  void _checkDndBypassOnResume() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 1));
      final supabaseService = GetIt.instance<SupabaseService>();
      if (supabaseService.currentUser == null) return;

      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('has_shown_dnd_dialog') ?? false)) {
          final isGranted = await NotificationService.isDndBypassGranted();
          if (!isGranted && context.mounted) {
            await NotificationService.showDndBypassDialog(context);
            await prefs.setBool('has_shown_dnd_dialog', true);
          }
        }
      }
    });
  }

  Future<void> _checkSessionOnResume() async {
    try {
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user == null) {
        final context = _navigatorKey.currentContext;
        if (context != null) {
          final currentRoute = ModalRoute.of(context)?.settings.name;
          if (!['/', '/login', '/splash', '/onboarding'].contains(currentRoute)) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        }
        return;
      }

      await supabaseService.getProfile(user.id);
    } catch (e) {
      _handleSessionExpired();
    }
  }

  Future<void> _syncDailyCacheOnResume() async {
    try {
      final dailyCache = GetIt.instance<DailyCacheService>();
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user != null && dailyCache.shouldSync()) {
        final perfil = await supabaseService.getProfile(user.id);
        if (perfil != null) await dailyCache.syncDailyData(perfil.id);
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao sincronizar cache: $e');
    }
  }

  void _setupFCMForegroundHandler() {
    if (kIsWeb) return;
    NotificationService.onForegroundMessage = (RemoteMessage message) {
      _showInAppNotification(message);
      _refreshNotifications();
    };
    NotificationService.onNotificationTapped = (int id) => _navigateToMedication(id);
  }

  void _setupFCMErrorHandlers() {
    if (kIsWeb) return;
    NotificationService.onFcmPermissionDenied = (msg) => _showFCMErrorDialog(msg, isPermission: true);
    NotificationService.onFcmTokenError = _showFCMErrorSnackbar;
    NotificationService.onFcmInitializationError = _showFCMErrorSnackbar;
    try {
      GetIt.instance<FCMTokenService>().onSyncError = _showFCMErrorSnackbar;
    } catch (_) {}
  }

  void _showFCMErrorDialog(String message, {bool isPermission = false}) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Notificações Desabilitadas'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
        ],
      ),
    );
  }

  void _showFCMErrorSnackbar(String message) {
    if (_navigatorKey.currentContext != null) {
      FeedbackService.showWarning(_navigatorKey.currentContext!, message);
    }
  }

  void _setupAuthStateListener() {
    try {
      GetIt.instance<SupabaseService>().authStateChanges.listen((data) {
        if (data.event == AuthChangeEvent.signedOut || (data.event == AuthChangeEvent.tokenRefreshed && data.session == null)) {
          _handleSessionExpired();
        }
      });
    } catch (_) {}
  }

  void _handleSessionExpired() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (['/', '/login', '/splash'].contains(currentRoute)) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sessão Expirada'),
        content: const Text('Sua sessão expirou. Faça login novamente.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: const Text('Fazer Login'),
          ),
        ],
      ),
    );
  }

  void _showInAppNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final context = _navigatorKey.currentContext;
    if (context != null) {
      InAppNotification.show(
        context,
        titulo: notification.title ?? '💊 CareMind',
        mensagem: notification.body ?? '',
        onTap: () => _navigatorKey.currentState?.pushNamed('/alertas'),
      );
    }
  }

  void _refreshNotifications() {
    try {
      final service = GetIt.instance<NotificacoesAppService>();
      service.atualizarContagem();
      service.carregarNotificacoes();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AccessibilityWrapper(
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeNotifier,
        builder: (context, themeMode, _) {
          return MaterialApp.router(
            routerConfig: AppRouter.router,
            title: 'CareMind',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themeData.copyWith(scaffoldBackgroundColor: Colors.transparent),
            darkTheme: AppTheme.darkTheme.copyWith(scaffoldBackgroundColor: Colors.transparent),
            themeMode: themeMode,
            builder: (context, child) => Stack(
              children: [const GlobalWaveBackground(), child!],
            ),
          );
        },
      ),
    );
  }
}
