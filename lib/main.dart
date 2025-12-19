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
import 'core/deep_link/deep_link_handler.dart';
import 'screens/auth/processar_convite_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/medicamento_service.dart';

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
  
  // Re-agendar todas as notificações de medicamentos após inicialização
  await rescheduleAllMedications();
  
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

/// Re-agendar todas as notificações de medicamentos
/// 
/// Esta função garante que todas as notificações sejam re-agendadas:
/// - Na inicialização do app
/// - Após reboot do dispositivo
/// - Quando o app retorna do background
/// 
/// Isso é crítico para garantir que as notificações não sejam perdidas
/// mesmo após reinicializações do sistema.
Future<void> rescheduleAllMedications() async {
  try {
    final supabaseService = GetIt.instance<SupabaseService>();
    final user = supabaseService.currentUser;
    
    if (user == null) {
      debugPrint('ℹ️ rescheduleAllMedications: Usuário não autenticado, pulando re-agendamento');
      return;
    }
    
    debugPrint('🔄 rescheduleAllMedications: Iniciando re-agendamento de notificações...');
    
    // Buscar todos os medicamentos do usuário
    final medicamentoService = MedicamentoService(supabaseService.client);
    final medicamentos = await medicamentoService.getMedicamentos(user.id);
    
    if (medicamentos.isEmpty) {
      debugPrint('ℹ️ rescheduleAllMedications: Nenhum medicamento encontrado');
      return;
    }
    
    debugPrint('📋 rescheduleAllMedications: ${medicamentos.length} medicamento(s) encontrado(s)');
    
    // Re-agendar notificações para cada medicamento
    int sucessos = 0;
    int falhas = 0;
    
    for (final medicamento in medicamentos) {
      try {
        await NotificationService.scheduleMedicationReminders(medicamento);
        sucessos++;
      } catch (e) {
        falhas++;
        debugPrint('❌ rescheduleAllMedications: Erro ao re-agendar ${medicamento.nome}: $e');
      }
    }
    
    debugPrint('✅ rescheduleAllMedications: Concluído - $sucessos sucesso(s), $falhas falha(s)');
  } catch (e, stackTrace) {
    debugPrint('❌ rescheduleAllMedications: Erro crítico - $e');
    debugPrint('Stack trace: $stackTrace');
    // Não relançar erro - não deve bloquear inicialização do app
  }
}

class CareMindApp extends StatefulWidget {
  const CareMindApp({super.key});

  @override
  State<CareMindApp> createState() => _CareMindAppState();
  
  // Método estático para mudar o tema de qualquer lugar do app
  static void changeThemeMode(ThemeMode mode) {
    _CareMindAppState.setThemeMode(mode);
  }
  
  // Método estático para verificar DND bypass após login
  static Future<void> checkDndBypassOnLogin(BuildContext? context) async {
    if (context == null || !context.mounted) return;
    
    try {
      // Verificar se o usuário está logado
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) {
        debugPrint('ℹ️ DND Bypass: Usuário não logado, pulando verificação');
        return;
      }
      
      // Verificar se já foi mostrado antes
      final prefs = await SharedPreferences.getInstance();
      final hasShownDndDialog = prefs.getBool('has_shown_dnd_dialog') ?? false;
      
      // Mostrar apenas uma vez
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
  ThemeMode _themeMode = ThemeMode.system; // Suporta system, light, dark
  static final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

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
  
  /// Verificar bypass de DND após inicialização do app
  /// 
  /// Aguarda um frame para garantir que o contexto está disponível,
  /// então verifica e mostra dialog se necessário.
  /// IMPORTANTE: Só mostra se o usuário estiver logado.
  void _checkDndBypassAfterInit() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Aguardar um pouco para garantir que o app está totalmente inicializado
      await Future.delayed(const Duration(seconds: 2));
      
      // Verificar se o usuário está logado antes de mostrar o dialog
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) {
        debugPrint('ℹ️ DND Bypass: Usuário não logado, pulando verificação');
        return;
      }
      
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        // Verificar se já foi mostrado antes (usar SharedPreferences)
        final prefs = await SharedPreferences.getInstance();
        final hasShownDndDialog = prefs.getBool('has_shown_dnd_dialog') ?? false;
        
        // Mostrar apenas uma vez, a menos que o usuário queira ver novamente
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
      // Carregar preferência de tema do SharedPreferences
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
    
    // Processar link inicial se houver
    if (_deepLinkHandler.initialLink != null) {
      _processDeepLink(_deepLinkHandler.initialLink!);
    }
    
    // Escutar novos deep links
    _deepLinkHandler.linkStream.listen((uri) {
      _processDeepLink(uri);
    });
  }

  void _processDeepLink(Uri uri) {
    try {
      final route = DeepLinkHandler.parseRoute(uri);
      
      if (route == null) {
        debugPrint('⚠️ DeepLink: Rota não reconhecida - $uri');
        return;
      }
      
      if (route == DeepLinkRoute.conviteIdoso) {
        try {
          final token = DeepLinkHandler.extractConviteToken(uri);
          final codigo = DeepLinkHandler.extractConviteCodigo(uri);
          
      if (token != null || codigo != null) {
        final tokenOuCodigo = token ?? codigo ?? '';
        if (tokenOuCodigo.isEmpty) return;
            final context = _navigatorKey.currentContext;
            if (context != null && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProcessarConviteScreen(
                    tokenOuCodigo: tokenOuCodigo,
                  ),
                ),
              );
            } else {
              debugPrint('⚠️ DeepLink: Context não disponível para navegação');
            }
          } else {
            debugPrint('⚠️ DeepLink: Token e código não encontrados no URI');
          }
        } catch (e) {
          debugPrint('❌ DeepLink: Erro ao processar convite - $e');
        }
      } else if (route == DeepLinkRoute.medicamento) {
        try {
          final medicamentoId = DeepLinkHandler.extractMedicamentoId(uri);
          if (medicamentoId != null && medicamentoId > 0) {
            _navigateToMedication(medicamentoId);
          } else {
            debugPrint('⚠️ DeepLink: ID de medicamento inválido ou não encontrado');
          }
        } catch (e) {
          debugPrint('❌ DeepLink: Erro ao processar medicamento - $e');
        }
      }
    } catch (e) {
      debugPrint('❌ DeepLink: Erro crítico ao processar deep link - $e');
    }
  }
  
  void _navigateToMedication(int medicamentoId) {
    try {
      if (medicamentoId <= 0) {
        debugPrint('⚠️ DeepLink: ID de medicamento inválido: $medicamentoId');
        return;
      }
      
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        debugPrint('⚠️ DeepLink: Context não disponível para navegação');
        return;
      }
      
      // Navegar para dashboard e destacar o medicamento
      // TODO: Implementar navegação específica para o medicamento
      // Por enquanto, navegar para dashboard
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/dashboard',
        (route) => false,
        arguments: {'highlightMedicationId': medicamentoId},
      );
    } catch (e) {
      debugPrint('❌ DeepLink: Erro ao navegar para medicamento - $e');
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
      // Re-agendar notificações quando o app retorna do background
      rescheduleAllMedications();
      // Verificar DND bypass se usuário estiver logado
      _checkDndBypassOnResume();
    }
  }
  
  /// Verificar bypass de DND quando o app retorna do background
  /// 
  /// Só verifica se o usuário estiver logado.
  void _checkDndBypassOnResume() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Aguardar um pouco para garantir que o app está totalmente carregado
      await Future.delayed(const Duration(seconds: 1));
      
      // Verificar se o usuário está logado
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) {
        return; // Usuário não logado, não mostrar
      }
      
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        // Verificar se já foi mostrado antes
        final prefs = await SharedPreferences.getInstance();
        final hasShownDndDialog = prefs.getBool('has_shown_dnd_dialog') ?? false;
        
        // Mostrar apenas uma vez
        if (!hasShownDndDialog && context.mounted) {
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
        // Se não há usuário, verificar se precisa redirecionar
        final context = _navigatorKey.currentContext;
        if (context != null) {
          final currentRoute = ModalRoute.of(context)?.settings.name;
          // Só redirecionar se não estiver já em uma tela de auth
          if (currentRoute != '/' && 
              currentRoute != '/login' && 
              currentRoute != '/splash' &&
              currentRoute != '/onboarding') {
            debugPrint('🔒 Nenhum usuário autenticado ao retomar app');
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          }
        }
        return;
      }
      
      // Verificar se a sessão ainda é válida tentando buscar o perfil
      try {
        await supabaseService.getProfile(user.id);
        debugPrint('✅ Sessão válida ao retomar app');
      } catch (e) {
        // Se falhar, a sessão pode ter expirado
        debugPrint('⚠️ Sessão inválida ao retomar app: $e');
        _handleSessionExpired();
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar sessão ao retomar: $e');
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
    
    // Configurar callback para quando notificação é tocada
    NotificationService.onNotificationTapped = (int medicamentoId) {
      _navigateToMedication(medicamentoId);
    };
  }

  void _setupFCMErrorHandlers() {
    if (kIsWeb) return;
    
    // Handler para permissão negada
    NotificationService.onFcmPermissionDenied = (String message) {
      _showFCMErrorDialog(message, isPermission: true);
    };
    
    // Handler para erro ao obter token
    NotificationService.onFcmTokenError = (String message) {
      _showFCMErrorSnackbar(message);
    };
    
    // Handler para erro de inicialização
    NotificationService.onFcmInitializationError = (String message) {
      _showFCMErrorSnackbar(message);
    };
    
    // Configurar callback de erro no FCMTokenService
    try {
      final fcmTokenService = GetIt.instance<FCMTokenService>();
      fcmTokenService.onSyncError = (String message) {
        _showFCMErrorSnackbar(message);
      };
    } catch (e) {
      debugPrint('⚠️ Erro ao configurar FCMTokenService error handler: $e');
    }
  }

  void _showFCMErrorDialog(String message, {bool isPermission = false}) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Notificações Desabilitadas'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
          if (isPermission)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Abrir configurações do dispositivo (se possível)
                // Nota: Requer package como app_settings
              },
              child: const Text('Abrir Configurações'),
            ),
        ],
      ),
    );
  }

  void _showFCMErrorSnackbar(String message) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _setupAuthStateListener() {
    try {
      final supabaseService = GetIt.instance<SupabaseService>();
      supabaseService.authStateChanges.listen((data) {
        final event = data.event;
        final session = data.session;
        
        debugPrint('🔄 AuthStateChange: $event');
        
        // Se a sessão expirou ou foi invalidada
        if (event == AuthChangeEvent.signedOut || 
            event == AuthChangeEvent.tokenRefreshed && session == null) {
          _handleSessionExpired();
        }
        
        // Se o token foi atualizado mas há sessão, verificar se ainda é válida
        if (event == AuthChangeEvent.tokenRefreshed && session != null) {
          _verifySessionValidity();
        }
      });
    } catch (e) {
      debugPrint('⚠️ Erro ao configurar auth state listener: $e');
    }
  }

  void _handleSessionExpired() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    
    // Verificar se já está na tela de login para evitar loops
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/' || currentRoute == '/login' || currentRoute == '/splash') {
      return;
    }
    
    debugPrint('🔒 Sessão expirada, redirecionando para login...');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sessão Expirada'),
        content: const Text(
          'Sua sessão expirou por segurança. Por favor, faça login novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            },
            child: const Text('Fazer Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifySessionValidity() async {
    try {
      final supabaseService = GetIt.instance<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) {
        _handleSessionExpired();
        return;
      }
      
      // Tentar fazer uma chamada simples para verificar se a sessão ainda é válida
      try {
        await supabaseService.getProfile(user.id);
      } catch (e) {
        // Se falhar, a sessão pode ter expirado
        debugPrint('⚠️ Verificação de sessão falhou: $e');
        _handleSessionExpired();
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar validade da sessão: $e');
    }
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
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeNotifier,
        builder: (context, themeMode, _) {
          // Atualizar estado local quando o notifier muda
          if (_themeMode != themeMode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _themeMode = themeMode;
                });
              }
            });
          }
          
          return MaterialApp(
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
            darkTheme: AppTheme.darkTheme.copyWith(
              scaffoldBackgroundColor: Colors.transparent,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            themeMode: themeMode,
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
          );
        },
      ),
    );
  }
}
