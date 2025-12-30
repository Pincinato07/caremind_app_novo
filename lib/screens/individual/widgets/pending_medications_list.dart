import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/caremind_card.dart';
import '../../../models/medicamento.dart';
import '../../../services/accessibility_service.dart';
import '../../../core/injection/injection.dart';

class PendingMedicationsList extends StatelessWidget {
  final List<Medicamento> medicamentosPendentes;
  final Map<int, bool> statusMedicamentos;
  final Map<int, bool> loadingMedicamentos;
  final Function(Medicamento) onConfirmSingle;
  final Function(List<Medicamento>) onConfirmBatch;
  final bool isSelectionMode;
  final VoidCallback onToggleSelectionMode;

  const PendingMedicationsList({
    super.key,
    required this.medicamentosPendentes,
    required this.statusMedicamentos,
    required this.loadingMedicamentos,
    required this.onConfirmSingle,
    required this.onConfirmBatch,
    required this.isSelectionMode,
    required this.onToggleSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    if (medicamentosPendentes.isEmpty) {
      return const SizedBox.shrink();
    }

    return CareMindCard(
      variant: CardVariant.solid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.small + 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Medicamentos Pendentes',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (!isSelectionMode && medicamentosPendentes.length > 1)
                IconButton(
                  onPressed: onToggleSelectionMode,
                  icon: const Icon(Icons.checklist),
                  color: AppColors.primary,
                  tooltip: 'Seleção múltipla',
                ),
            ],
          ),
          const SizedBox(height: 16),
          BatchMedicationSelector(
            medications: medicamentosPendentes,
            statusMedicamentos: statusMedicamentos,
            loadingMedicamentos: loadingMedicamentos,
            onConfirmSingle: onConfirmSingle,
            onConfirmBatch: onConfirmBatch,
            isSelectionMode: isSelectionMode,
            onToggleSelectionMode: onToggleSelectionMode,
          ),
        ],
      ),
    );
  }
}
