import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/medicamento.dart';
import 'confirm_medication_button.dart';

/// Widget para seleção múltipla e confirmação em lote de medicamentos
class BatchMedicationSelector extends StatefulWidget {
  final List<Medicamento> medications;
  final Map<int, bool> statusMedicamentos;
  final Map<int, bool> loadingMedicamentos;
  final Function(Medicamento) onConfirmSingle;
  final Function(List<Medicamento>) onConfirmBatch;
  final bool isSelectionMode;
  final VoidCallback onToggleSelectionMode;

  const BatchMedicationSelector({
    super.key,
    required this.medications,
    required this.statusMedicamentos,
    required this.loadingMedicamentos,
    required this.onConfirmSingle,
    required this.onConfirmBatch,
    required this.isSelectionMode,
    required this.onToggleSelectionMode,
  });

  @override
  State<BatchMedicationSelector> createState() =>
      _BatchMedicationSelectorState();
}

class _BatchMedicationSelectorState extends State<BatchMedicationSelector> {
  final Set<int> _selectedMedications = {};

  @override
  void initState() {
    super.initState();
    // Quando sair do modo de seleção, limpar seleções
    if (!widget.isSelectionMode) {
      _selectedMedications.clear();
    }
  }

  @override
  void didUpdateWidget(BatchMedicationSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Limpar seleções quando sair do modo de seleção
    if (oldWidget.isSelectionMode && !widget.isSelectionMode) {
      _selectedMedications.clear();
    }
  }

  void _toggleSelection(int medicationId) {
    try {
      if (medicationId <= 0) {
        debugPrint(
            '⚠️ BatchMedicationSelector: ID de medicamento inválido: $medicationId');
        return;
      }

      setState(() {
        if (_selectedMedications.contains(medicationId)) {
          _selectedMedications.remove(medicationId);
        } else {
          _selectedMedications.add(medicationId);
        }
      });
    } catch (e) {
      debugPrint('❌ BatchMedicationSelector: Erro ao alternar seleção - $e');
    }
  }

  void _confirmBatch() {
    try {
      final selected = widget.medications
          .where((m) => m.id != null && _selectedMedications.contains(m.id))
          .toList();

      if (selected.isEmpty) {
        debugPrint(
            '⚠️ BatchMedicationSelector: Nenhum medicamento selecionado');
        return;
      }

      if (selected.length != _selectedMedications.length) {
        debugPrint(
            '⚠️ BatchMedicationSelector: Inconsistência entre seleções e medicamentos');
      }

      widget.onConfirmBatch(selected);
      setState(() {
        _selectedMedications.clear();
      });
    } catch (e) {
      debugPrint('❌ BatchMedicationSelector: Erro ao confirmar lote - $e');
      // Não limpar seleções em caso de erro para permitir retry
    }
  }

  void _selectAll() {
    try {
      setState(() {
        _selectedMedications.clear();
        for (var med in widget.medications) {
          if (med.id != null &&
              med.id! > 0 &&
              !(widget.statusMedicamentos[med.id] ?? false)) {
            _selectedMedications.add(med.id!);
          }
        }
      });
    } catch (e) {
      debugPrint('❌ BatchMedicationSelector: Erro ao selecionar todos - $e');
    }
  }

  void _deselectAll() {
    setState(() {
      _selectedMedications.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.medications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de ações do modo de seleção
        if (widget.isSelectionMode)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedMedications.length} selecionado(s)',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Toque nos medicamentos para selecionar',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _selectedMedications.length ==
                          widget.medications
                              .where((m) =>
                                  m.id != null &&
                                  !(widget.statusMedicamentos[m.id] ?? false))
                              .length
                      ? _deselectAll
                      : _selectAll,
                  child: Text(
                    _selectedMedications.length ==
                            widget.medications
                                .where((m) =>
                                    m.id != null &&
                                    !(widget.statusMedicamentos[m.id] ?? false))
                                .length
                        ? 'Desmarcar todos'
                        : 'Selecionar todos',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onToggleSelectionMode,
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

        if (widget.isSelectionMode) const SizedBox(height: 12),

        // Lista de medicamentos
        ...widget.medications.map((med) {
          final isLoading = widget.loadingMedicamentos[med.id] ?? false;
          final isConfirmed = widget.statusMedicamentos[med.id] ?? false;
          final isSelected =
              med.id != null && _selectedMedications.contains(med.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: widget.isSelectionMode && !isConfirmed
                  ? () => _toggleSelection(med.id!)
                  : null,
              child: Container(
                decoration: widget.isSelectionMode && isSelected
                    ? BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      )
                    : null,
                padding: widget.isSelectionMode
                    ? const EdgeInsets.all(8)
                    : EdgeInsets.zero,
                child: Row(
                  children: [
                    if (widget.isSelectionMode && !isConfirmed)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (value) => _toggleSelection(med.id!),
                          activeColor: AppColors.primary,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med.nome,
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (med.dosagem != null)
                            Text(
                              med.dosagem!,
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!widget.isSelectionMode)
                      ConfirmMedicationButton(
                        isConfirmed: isConfirmed,
                        isLoading: isLoading,
                        onConfirm: () => widget.onConfirmSingle(med),
                        onUndo: () => widget.onConfirmSingle(med),
                        medicationName: med.nome,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),

        // Botão de confirmação em lote
        if (widget.isSelectionMode && _selectedMedications.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmBatch,
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: Text(
                  'Confirmar ${_selectedMedications.length} medicamento(s)',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
