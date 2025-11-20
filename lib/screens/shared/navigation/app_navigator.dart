import 'package:flutter/material.dart';
import '../../../models/perfil.dart';
import 'idoso_navigation_shell.dart';
import 'familiar_navigation_shell.dart';
import 'individual_navigation_shell.dart';

/// Factory de Navegação
/// Decide qual "Árvore de Widgets" construir baseado no tipo de perfil
class AppNavigator extends StatelessWidget {
  final Perfil perfil;

  const AppNavigator({
    super.key,
    required this.perfil,
  });

  @override
  Widget build(BuildContext context) {
    final tipoLower = perfil.tipo?.toLowerCase();

    // Factory: Decide qual shell de navegação usar
    if (tipoLower == 'idoso') {
      return const IdosoNavigationShell();
    } else if (tipoLower == 'familiar') {
      return const FamiliarNavigationShell();
    } else {
      // Default: Individual ou qualquer outro tipo
      return const IndividualNavigationShell();
    }
  }
}

