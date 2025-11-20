import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_shell.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/individual/dashboard_screen.dart';
import 'screens/familiar/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/global_wave_background.dart';
import 'core/injection/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Configura injeção de dependências
  await configureDependencies();
  
  runApp(const CareMindApp());
}

class CareMindApp extends StatelessWidget {
  const CareMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      },
    );
  }
}
