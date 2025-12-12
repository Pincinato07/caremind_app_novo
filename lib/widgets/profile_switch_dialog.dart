import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/perfil.dart';
import '../core/injection/injection.dart';
import '../services/supabase_service.dart';

/// Dialog de troca de perfil com limpeza de pilha de navegação
/// Previne bugs de "botão voltar misturando perfis"
class ProfileSwitchDialog extends StatelessWidget {
  final List<Perfil> profiles;
  final Perfil? currentProfile;

  const ProfileSwitchDialog({
    super.key,
    required this.profiles,
    this.currentProfile,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Perfil> profiles,
    Perfil? currentProfile,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ProfileSwitchDialog(
        profiles: profiles,
        currentProfile: currentProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.small),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trocar Perfil',
                        style: AppTextStyles.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selecione o perfil que deseja usar',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.large),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.medium),
            ...profiles.map((profile) => _buildProfileOption(
                  context,
                  profile,
                  isCurrentProfile: profile.id == currentProfile?.id,
                )),
            const SizedBox(height: AppSpacing.medium),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context,
    Perfil profile, {
    bool isCurrentProfile = false,
  }) {
    final config = _getProfileConfig(profile.tipo);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCurrentProfile
              ? null
              : () => _switchProfile(context, profile),
          borderRadius: BorderRadius.circular(AppBorderRadius.small),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.medium),
            decoration: BoxDecoration(
              color: isCurrentProfile
                  ? config.color.withOpacity(0.1)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              border: Border.all(
                color: isCurrentProfile
                    ? config.color
                    : AppColors.border,
                width: isCurrentProfile ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.small),
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    config.icon,
                    color: config.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profile.nome ?? 'Sem nome',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: isCurrentProfile
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          if (isCurrentProfile) ...[
                            const SizedBox(width: AppSpacing.small),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: config.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ATIVO',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCurrentProfile)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ProfileConfig _getProfileConfig(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'individual':
        return _ProfileConfig(
          label: 'Conta Individual',
          icon: Icons.person,
          color: AppColors.info,
        );
      case 'familiar':
        return _ProfileConfig(
          label: 'Conta Familiar/Cuidador',
          icon: Icons.groups,
          color: AppColors.accent,
        );
      case 'idoso':
        return _ProfileConfig(
          label: 'Conta Idoso',
          icon: Icons.elderly,
          color: AppColors.success,
        );
      default:
        return _ProfileConfig(
          label: 'Conta Desconhecida',
          icon: Icons.person_outline,
          color: AppColors.textSecondary,
        );
    }
  }

  Future<void> _switchProfile(BuildContext context, Perfil profile) async {
    try {
      // Fechar o dialog
      Navigator.of(context).pop();

      // Mostrar loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Trocar perfil (implementar lógica de troca aqui)
      // await getIt<ProfileService>().switchProfile(profile.id);

      // CRITICAL: Limpar pilha de navegação para evitar bugs
      if (context.mounted) {
        // Fechar loading
        Navigator.of(context).pop();
        
        // Redirecionar baseado no tipo de perfil
        final route = _getRouteForProfile(profile.tipo);
        Navigator.of(context).pushNamedAndRemoveUntil(
          route,
          (route) => false, // Remove TODAS as rotas anteriores
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Fechar loading se aberto
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao trocar perfil: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getRouteForProfile(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'individual':
        return '/individual';
      case 'familiar':
        return '/familiar';
      case 'idoso':
        return '/idoso';
      default:
        return '/';
    }
  }
}

class _ProfileConfig {
  final String label;
  final IconData icon;
  final Color color;

  _ProfileConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
