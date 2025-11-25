import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'widgets/global_wave_background.dart';
import 'widgets/accessibility_wrapper.dart';
import 'core/injection/injection.dart';
import 'services/notification_service.dart';
import 'services/fcm_token_service.dart';
import 'package:get_it/get_it.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carregar variáveis de ambiente
  await dotenv.load(fileName: ".env");

  // IMPORTANTE: Firebase é usado APENAS para FCM (Firebase Cloud Messaging)
  // Isso é necessário tecnicamente para push notifications remotas funcionarem
  // TODO o backend e gerenciamento usa Supabase
  // 
  // Você precisa adicionar os arquivos de configuração FCM:
  // - android/app/google-services.json (obtido do Firebase Console - apenas para FCM)
  // - ios/Runner/GoogleService-Info.plist (obtido do Firebase Console - apenas para FCM)
  // 
  // NOTA: Firebase/FCM não funciona na web, então só inicializamos em plataformas móveis
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase inicializado (apenas para FCM - push notifications)');
      
      // Configurar handler para notificações FCM em background/terminated
      // Esta função DEVE estar no nível superior (definida em notification_service.dart)
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      debugPrint('✅ Handler de background FCM configurado');
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar Firebase (FCM): $e');
      debugPrint('⚠️ Notificações push podem não funcionar. Verifique os arquivos de configuração do FCM.');
    }
  } else {
    debugPrint('ℹ️ Firebase não inicializado na web (FCM não suportado na web)');
  }

  // Inicializar Supabase (backend principal - autenticação, banco de dados, Edge Functions)
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception('SUPABASE_URL não encontrado no arquivo .env');
  }
  
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('SUPABASE_ANON_KEY não encontrado no arquivo .env');
  }
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  debugPrint('✅ Supabase inicializado (backend principal)');

  // Configurar injeção de dependências (já feito antes da splash)
  // A splash screen agora vai fazer verificações de autenticação
  await configureDependencies();
  
  // Inicializar FCM Token Service para sincronizar tokens FCM com Supabase
  // Os tokens são armazenados no Supabase e usados pelas Edge Functions para enviar push notifications
  // NOTA: FCM não funciona na web, então só inicializamos em plataformas móveis
  if (!kIsWeb) {
    try {
      final fcmTokenService = GetIt.instance<FCMTokenService>();
      await fcmTokenService.initialize();
      debugPrint('✅ FCMTokenService inicializado (tokens sincronizados com Supabase)');
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar FCMTokenService: $e');
    }
  } else {
    debugPrint('ℹ️ FCMTokenService não inicializado na web (FCM não suportado na web)');
  }
  
  runApp(const CareMindApp());
}

class CareMindApp extends StatelessWidget {
  const CareMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AccessibilityWrapper(
      child: MaterialApp(
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
              // Global background with waves that persists across all screens
              const GlobalWaveBackground(),
              
              // Main app content
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
      },
      ),
    );
  }
}
