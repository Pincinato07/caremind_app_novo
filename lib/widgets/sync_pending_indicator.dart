import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_theme.dart';

/// Provider para contar ações pendentes
final pendingActionsCountProvider =
    StreamProvider<Map<String, int>>((ref) async* {
  while (true) {
    final counts = await OfflineCacheService.getPendingActionsCount();
    yield counts;
    await Future.delayed(const Duration(seconds: 2));
  }
});

/// Widget que exibe indicador discreto de dados pendentes de sincronização
///
/// Mostra um ícone de nuvem com badge quando há dados salvos localmente
/// aguardando sincronização
class SyncPendingIndicator extends ConsumerWidget {
  final Color? iconColor;
  final double iconSize;
  final bool showBadge;

  const SyncPendingIndicator({
    super.key,
    this.iconColor,
    this.iconSize = 24,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingActionsCountProvider);

    return pendingAsync.when(
      data: (counts) {
        final total = counts.values.fold<int>(0, (sum, count) => sum + count);

        if (total == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _showPendingDetails(context, counts),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                color: iconColor ?? AppColors.warning,
                size: iconSize,
              ),
              if (showBadge && total > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      total > 9 ? '9+' : '$total',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showPendingDetails(BuildContext context, Map<String, int> counts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppBorderRadius.large)),
      ),
      builder: (context) => Container(
        padding: AppSpacing.paddingLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload, color: AppColors.warning, size: 28),
                SizedBox(width: AppSpacing.medium),
                Text(
                  'Dados Pendentes',
                  style: AppTextStyles.headlineSmall,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.medium),
            Text(
              'Os seguintes dados estão salvos localmente e serão sincronizados automaticamente quando voltar online:',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: AppSpacing.medium),
            if (counts['add_medicamento'] != null &&
                counts['add_medicamento']! > 0)
              _buildPendingItem(
                context,
                Icons.medication,
                'Medicamentos a adicionar',
                counts['add_medicamento']!,
              ),
            if (counts['toggle_concluido'] != null &&
                counts['toggle_concluido']! > 0)
              _buildPendingItem(
                context,
                Icons.check_circle,
                'Confirmações de medicação',
                counts['toggle_concluido']!,
              ),
            if (counts['ocr_upload'] != null && counts['ocr_upload']! > 0)
              _buildPendingItem(
                context,
                Icons.document_scanner,
                'Imagens de receitas',
                counts['ocr_upload']!,
              ),
            SizedBox(height: AppSpacing.medium),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                ),
                child: Text(
                  'Entendi',
                  style: AppTextStyles.labelLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingItem(
    BuildContext context,
    IconData icon,
    String label,
    int count,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.small + 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.warning, size: 24),
          SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyLarge,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.small,
            ),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
