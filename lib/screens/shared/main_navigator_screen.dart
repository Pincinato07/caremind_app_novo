// lib/screens/main_navigator_screen.dart

import 'package:flutter/material.dart';
import '../../models/perfil.dart';
import 'navigation/app_navigator.dart';

/// Tela principal de navegação
/// Usa o AppNavigator factory para decidir qual shell de navegação construir
class MainNavigatorScreen extends StatelessWidget {
  final Perfil perfil;

  const MainNavigatorScreen({super.key, required this.perfil});

  @override
  Widget build(BuildContext context) {
    // Factory: AppNavigator decide qual "Árvore de Widgets" construir
    return AppNavigator(perfil: perfil);
  }
}
