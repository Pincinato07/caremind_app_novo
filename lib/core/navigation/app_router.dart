import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/splash_screen.dart';
import '../../screens/auth/auth_shell.dart';
import '../../screens/auth/onboarding_screen.dart';
import '../../screens/individual/dashboard_screen.dart';
import '../../screens/familiar/dashboard_screen.dart';
import '../../screens/shared/configuracoes_screen.dart';
import '../../screens/shared/perfil_screen.dart';
import '../../screens/medication/gestao_medicamentos_screen.dart';
import '../../screens/rotinas/gestao_rotinas_screen.dart';
import '../../screens/compromissos/gestao_compromissos_screen.dart';
import '../../screens/integracoes/integracoes_screen.dart';
import '../../screens/shared/alertas_screen.dart';
import '../../screens/auth/processar_convite_screen.dart';
import '../../screens/individual/widgets/registrar_evento_form.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const AuthShell(initialMode: AuthMode.login),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const AuthShell(initialMode: AuthMode.login),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const AuthShell(initialMode: AuthMode.register),
      ),
      GoRoute(
        path: '/individual-dashboard',
        name: 'individual-dashboard',
        builder: (context, state) => const IndividualDashboardScreen(),
      ),
      GoRoute(
        path: '/familiar-dashboard',
        name: 'familiar-dashboard',
        builder: (context, state) => const FamiliarDashboardScreen(),
      ),
      GoRoute(
        path: '/configuracoes',
        name: 'configuracoes',
        builder: (context, state) => const ConfiguracoesScreen(),
      ),
      GoRoute(
        path: '/perfil',
        name: 'perfil',
        builder: (context, state) => const PerfilScreen(),
      ),
      GoRoute(
        path: '/gestao-medicamentos',
        name: 'gestao-medicamentos',
        builder: (context, state) => const GestaoMedicamentosScreen(),
      ),
      GoRoute(
        path: '/gestao-rotinas',
        name: 'gestao-rotinas',
        builder: (context, state) => const GestaoRotinasScreen(),
      ),
      GoRoute(
        path: '/gestao-compromissos',
        name: 'gestao-compromissos',
        builder: (context, state) => const GestaoCompromissosScreen(),
      ),
      GoRoute(
        path: '/integracoes',
        name: 'integracoes',
        builder: (context, state) => const IntegracoesScreen(),
      ),
      GoRoute(
        path: '/alertas',
        name: 'alertas',
        builder: (context, state) => const AlertasScreen(),
      ),
      GoRoute(
        path: '/processar-convite',
        name: 'processar-convite',
        builder: (context, state) {
          final tokenOuCodigo = state.extra as String?;
          return ProcessarConviteScreen(tokenOuCodigo: tokenOuCodigo ?? '');
        },
      ),
      GoRoute(
        path: '/registrar-evento',
        name: 'registrar-evento',
        builder: (context, state) {
          final idosoId = state.extra as String?;
          return RegistrarEventoForm(idosoId: idosoId);
        },
      ),
    ],
  );
}
