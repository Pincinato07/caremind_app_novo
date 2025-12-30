import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/review_trigger_service.dart';

/// Modal gentil para solicitar avaliação após sucesso do usuário
class ReviewModal extends StatelessWidget {
  const ReviewModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const ReviewModal(),
    );
  }

  Future<void> _handlePositive(BuildContext context) async {
    Navigator.pop(context);
    try {
      await ReviewTriggerService.openStoreForReview();
    } catch (e) {
      // Erro ao abrir loja - apenas logar
      debugPrint('Erro ao abrir loja: $e');
    }
  }

  Future<void> _handleNegative(BuildContext context) async {
    Navigator.pop(context);
    // Reseta o streak para não mostrar novamente
    await ReviewTriggerService.resetStreak();
  }

  Future<void> _handleDismiss(BuildContext context) async {
    Navigator.pop(context);
    // Marca como já mostrado para não encher o saco
    await ReviewTriggerService.markAsShown();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.05),
            Colors.white,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle de arrastar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                
                // Ícone de coração/estrela
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                
                // Título
                Text(
                  'Estamos felizes em cuidar de você! 💚',
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.medium),
                
                // Mensagem
                Text(
                  'Você já marcou 10 remédios como tomados! Isso nos deixa muito felizes em saber que o CareMind está te ajudando.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.small),
                
                Text(
                  'Que tal nos avaliar no Google? Isso ajuda muito mais pessoas a encontrarem nosso app.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xlarge),
                
                // Botão principal
                ElevatedButton(
                  onPressed: () => _handlePositive(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Avaliar Agora',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                
                // Botão secundário
                OutlinedButton(
                  onPressed: () => _handleNegative(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Agora não',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                
                // Link "já avaliei"
                TextButton(
                  onPressed: () => _handleDismiss(context),
                  child: Text(
                    'Já avaliei o app',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
              ],
            ),
          );
        },
      ),
    );
  }
}

