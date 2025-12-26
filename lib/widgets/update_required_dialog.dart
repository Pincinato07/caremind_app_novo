import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../models/app_version.dart';
import '../core/config/app_config.dart';

/// Diálogo de atualização obrigatória - Estilo CareMind
/// Aparece na splash screen quando a versão está desatualizada
class UpdateRequiredDialog extends StatelessWidget {
  final AppVersion latestVersion;

  const UpdateRequiredDialog({
    super.key,
    required this.latestVersion,
  });

  static Future<void> show(
    BuildContext context, {
    required AppVersion latestVersion,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateRequiredDialog(latestVersion: latestVersion),
    );
  }

  Future<void> _launchDownloadUrl() async {
    // Usa o link do Supabase ou o link configurado
    final downloadUrl = latestVersion.downloadUrl.isNotEmpty 
        ? latestVersion.downloadUrl 
        : AppConfig.getDownloadUrl();
    
    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changelogLines = latestVersion.changelog?.split('\n').where((line) => line.trim().isNotEmpty).toList() ?? [];
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.6),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppBorderRadius.xlargeAll,
            boxShadow: AppShadows.large,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header com ícone e título
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppBorderRadius.mediumAll,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atualização Obrigatória',
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Versão ${latestVersion.versionName}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Mensagem principal
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppBorderRadius.mediumAll,
                ),
                child: Text(
                  'Uma atualização importante está disponível para continuar usando o CareMind com segurança e todas as funcionalidades.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              if (changelogLines.isNotEmpty) ...[
                const SizedBox(height: 16),
                // O que há de novo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppBorderRadius.mediumAll,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.new_releases, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'O que há de novo:',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...changelogLines.take(5).map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                line.trim(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Botões de ação
              Column(
                children: [
                  // Botão principal - Download
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _launchDownloadUrl,
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text('Baixar Atualização'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.mediumAll,
                        ),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Botão secundário - Verificar novamente
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // O splash screen vai verificar novamente
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Verificar Atualização'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.mediumAll,
                        ),
                        side: BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Informações técnicas
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppBorderRadius.smallAll,
                ),
                child: FutureBuilder<String>(
                  future: _getCurrentVersion(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    return Text(
                      'Versão atual: ${snapshot.data}  •  Nova: ${latestVersion.versionName}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      return AppConfig.getCurrentVersionFormatted();
    }
  }
}
