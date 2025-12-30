import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/caremind_card.dart';
import '../../../widgets/status_badge.dart';

class MedicationStatusCard extends StatelessWidget {
  final int medicamentosTomados;
  final int totalMedicamentos;
  final bool temAtraso;
  final String mensagemStatus;

  const MedicationStatusCard({
    super.key,
    required this.medicamentosTomados,
    required this.totalMedicamentos,
    required this.temAtraso,
    required this.mensagemStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status dos medicamentos',
      hint: 'Mostra se você está em dia com seus medicamentos',
      child: CareMindCard(
        variant: CardVariant.solid,
        borderColor: temAtraso
            ? AppColors.error.withValues(alpha: 0.5)
            : AppColors.success.withValues(alpha: 0.4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (temAtraso ? AppColors.error : AppColors.success)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                temAtraso ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: temAtraso ? AppColors.error : AppColors.success,
                size: 28,
              ),
            ),
            SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mensagemStatus,
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xsmall),
                  Text(
                    '$medicamentosTomados de $totalMedicamentos medicamentos tomados hoje',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
