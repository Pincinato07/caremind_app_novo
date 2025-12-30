import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/caremind_card.dart';
import '../../../models/medicamento.dart';
import '../../../services/accessibility_service.dart';
import '../../../core/injection/injection.dart';

class NextMedicationCard extends StatelessWidget {
  final Medicamento? proximoMedicamento;
  final TimeOfDay? proximoHorario;

  const NextMedicationCard({
    super.key,
    this.proximoMedicamento,
    this.proximoHorario,
  });

  @override
  Widget build(BuildContext context) {
    if (proximoMedicamento == null) {
      return Semantics(
        label: 'Medicamentos em dia',
        hint: 'Todos os medicamentos do dia foram tomados',
        child: CareMindCard(
          variant: CardVariant.solid,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 28,
                ),
              ),
              SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tudo tomado por hoje! ✅',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xsmall),
                    Text(
                      'Parabéns! Você está em dia com seus medicamentos.',
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

    final horarioStr = proximoHorario != null
        ? '${proximoHorario!.hour.toString().padLeft(2, '0')}:${proximoHorario!.minute.toString().padLeft(2, '0')}'
        : '';

    return Semantics(
      label: 'Próximo medicamento',
      hint: '${proximoMedicamento!.nome}, às $horarioStr. Toque para ouvir detalhes.',
      child: GestureDetector(
        onTap: () {
          AccessibilityService.speak(
            'Próximo medicamento: ${proximoMedicamento!.nome}, dosagem: ${proximoMedicamento!.dosagem ?? 'não especificada'}, horário: $horarioStr',
          );
        },
        child: CareMindCard(
          variant: CardVariant.solid,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication_liquid,
                      color: AppColors.accent,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Próximo Medicamento',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xsmall),
                        Text(
                          proximoMedicamento!.nome,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          horarioStr,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.small + 4),
                  Expanded(
                    child: Text(
                      proximoMedicamento!.dosagem ?? 'Dosagem não especificada',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
