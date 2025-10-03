import 'package:flutter/material.dart';
import '../../models/perfil.dart';
import '../familiar/dashboard_screen.dart';
import '../individual/dashboard_screen.dart' as individual;

class MainNavigatorScreen extends StatelessWidget {
  final Perfil perfil;

  const MainNavigatorScreen({Key? key, required this.perfil}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Verifica o tipo de perfil para determinar qual dashboard exibir
    if (perfil.tipo == 'familiar') {
      return FamiliarDashboardScreen();
    } else {
      return individual.IndividualDashboardScreen();
    }
  }
}
