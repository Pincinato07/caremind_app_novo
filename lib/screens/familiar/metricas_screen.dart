// lib/screens/metricas_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/app_scaffold_with_waves.dart';

class MetricasScreen extends StatelessWidget {
  const MetricasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: 'Métricas de Saúde',
        showBackButton: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.monitor_heart,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              'Tela de Métricas',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            const Text(
              'Registre suas métricas de saúde\n(pressão, glicemia, peso, etc.)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
