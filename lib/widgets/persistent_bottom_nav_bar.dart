import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../core/injection/injection.dart';
import 'nav_item.dart';

/// Widget que fornece o bottom navigation bar persistente
/// Detecta automaticamente o tipo de perfil e mostra os itens corretos
class PersistentBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const PersistentBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.98),
            Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            NavItem(
              icon: Icons.home_rounded,
              label: 'Início',
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            NavItem(
              icon: Icons.medication_liquid,
              label: 'Medicamentos',
              isSelected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            NavItem(
              icon: Icons.schedule_rounded,
              label: 'Rotina',
              isSelected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            NavItem(
              icon: Icons.settings_applications_rounded,
              label: 'Gestão',
              isSelected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}
