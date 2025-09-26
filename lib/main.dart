import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/family_role_selection_screen.dart';
import 'screens/link_account_screen.dart';
import 'screens/individual_dashboard_screen.dart';
import 'screens/familiar_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
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
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/family-role-selection': (context) => const FamilyRoleSelectionScreen(),
        '/link-account': (context) => const LinkAccountScreen(),
        '/individual-dashboard': (context) => const IndividualDashboardScreen(),
        '/familiar-dashboard': (context) => const FamiliarDashboardScreen(),
      },
    );
  }
}
