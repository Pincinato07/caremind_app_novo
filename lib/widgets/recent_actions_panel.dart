import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'caremind_card.dart';

/// Modelo para ações recentes de medicamentos
class MedicationAction {
  final int medicationId;
  final String medicationName;
  final DateTime timestamp;
  final bool isConfirmed;
  final VoidCallback onUndo;
  final bool canUndo;

  MedicationAction({
    required this.medicationId,
    required this.medicationName,
    required this.timestamp,
    required this.isConfirmed,
    required this.onUndo,
    this.canUndo = true,
  });

  /// Verifica se a ação ainda pode ser desfeita (dentro de 5 minutos)
  bool get isUndoable {
    if (!canUndo) return false;
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inMinutes < 5 && isConfirmed;
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Agora';
    } else if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Há ${difference.inHours} h';
    } else {
      return 'Há ${difference.inDays} dia(s)';
    }
  }
}

/// Painel de ações recentes de medicamentos
class RecentActionsPanel extends StatelessWidget {
  final List<MedicationAction> actions;
  final VoidCallback? onViewAll;

  const RecentActionsPanel({
    super.key,
    required this.actions,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final recentActions = actions.take(5).toList();

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
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ações Recentes',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    'Ver todas',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...recentActions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < recentActions.length - 1 ? 12 : 0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: action.isConfirmed
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      action.isConfirmed
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: action.isConfirmed
                          ? AppColors.success
                          : AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.medicationName,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              action.isConfirmed ? 'Confirmado' : 'Desmarcado',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              action.timeAgo,
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (action.isUndoable)
                    TextButton(
                      onPressed: () {
                        try {
                          action.onUndo();
                        } catch (e) {
                          debugPrint('❌ RecentActionsPanel: Erro ao desfazer ação - $e');
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        'Desfazer',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Expirado',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

