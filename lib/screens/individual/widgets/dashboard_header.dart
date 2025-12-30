```
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/accessibility_service.dart';
import '../../../widgets/offline_indicator.dart';

class DashboardHeader extends StatelessWidget {
  final String userName;
  final bool isOffline;
  final DateTime? lastSync;
  final VoidCallback onReadSummary;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.isOffline,
    this.lastSync,
    required this.onReadSummary,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Bom dia! Como está se sentindo hoje?';
    } else if (hour < 18) {
      return 'Boa tarde! Vamos cuidar da sua saúde?';
    } else {
      return 'Boa noite! Que tal revisar o dia?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Olá, $userName!',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (isOffline) const OfflineBadge(),
            const SizedBox(width: 8),
            Semantics(
              label: 'Botão ouvir resumo',
              hint: 'Lê em voz alta o resumo do seu dia',
              button: true,
              child: IconButton(
                onPressed: onReadSummary,
                icon: Icon(Icons.volume_up, color: AppColors.textSecondary),
                iconSize: 28,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _getGreeting(),
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (lastSync != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LastSyncInfo(lastSync: lastSync),
          ),
      ],
    );
  }
}
