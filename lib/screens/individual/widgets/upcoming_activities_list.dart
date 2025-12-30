import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/caremind_card.dart';
import '../../../services/accessibility_service.dart';
import '../../../core/injection/injection.dart';

class UpcomingActivitiesList extends StatelessWidget {
  final List<Map<String, dynamic>> rotinas;

  const UpcomingActivitiesList({
    super.key,
    required this.rotinas,
  });

  @override
  Widget build(BuildContext context) {
    final rotinasPendentes = rotinas
        .where((r) => (r['concluida'] as bool? ?? false) == false)
        .take(2)
        .toList();

    if (rotinasPendentes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Próximas atividades',
      hint: 'Lista das próximas rotinas e atividades',
      child: CareMindCard(
        variant: CardVariant.solid,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.small + 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppSpacing.small + 4),
                Text(
                  'Próximas Atividades',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...rotinasPendentes.asMap().entries.map((entry) {
              final index = entry.key;
              final rotina = entry.value;
              final nome = rotina['nome'] as String? ?? 'Atividade';
              final horario = rotina['horario'] as String? ?? '';

              return Semantics(
                label: 'Atividade $nome',
                hint: 'Horário: $horario. Toque para ouvir detalhes.',
                child: GestureDetector(
                  onTap: () {
                    AccessibilityService.speak(
                      'Atividade: $nome, horário: $horario',
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: index < rotinasPendentes.length - 1 ? 12 : 0),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: AppSpacing.small + 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nome,
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                horario,
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
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
