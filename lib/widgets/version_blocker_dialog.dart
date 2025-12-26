import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_version.dart';

/// Diálogo de bloqueio completo quando a versão é obrigatória e desatualizada
class VersionBlockerDialog extends StatelessWidget {
  final AppVersion latestVersion;

  const VersionBlockerDialog({
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
      builder: (context) => VersionBlockerDialog(latestVersion: latestVersion),
    );
  }

  Future<void> _launchDownloadUrl() async {
    final uri = Uri.parse(latestVersion.downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changelogLines = latestVersion.changelog?.split('\n').where((line) => line.trim().isNotEmpty).toList() ?? [];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.red.shade400, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ícone de alerta
                Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.update,
                    size: 32,
                    color: Colors.red.shade700,
                  ),
                ),

                // Título
                Text(
                  'Atualização Obrigatória',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),

                const SizedBox(height: 8),

                // Versão
                Text(
                  'Versão ${latestVersion.versionName} disponível',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 16),

                // Mensagem
                Text(
                  'Uma atualização importante está disponível para continuar usando o aplicativo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),

                if (changelogLines.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'O que há de novo:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...changelogLines.map((line) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  line.trim(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red.shade900,
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

                const SizedBox(height: 24),

                // Botões
                ElevatedButton.icon(
                  onPressed: _launchDownloadUrl,
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('Baixar Atualização'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),

                const SizedBox(height: 8),

                OutlinedButton.icon(
                  onPressed: () {
                    // Recarregar a tela para verificar novamente
                    Navigator.of(context).pop();
                    // O serviço de verificação será chamado novamente
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Verificar Atualização'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),

                const SizedBox(height: 8),

                // Informação da versão atual
                FutureBuilder<String>(
                  future: _getCurrentVersion(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    return Text(
                      'Versão atual: ${snapshot.data}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  },
                ),
              ],
            ),
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
      return 'Desconhecida';
    }
  }
}

// Classe auxiliar para acessar PackageInfo
class PackageInfo {
  static Future<PackageInfo> fromPlatform() async {
    // Implementação simplificada - na prática use package_info_plus
    return PackageInfo._(
      appName: 'CareMind',
      packageName: 'com.caremind.app',
      version: '1.1.4',
      buildNumber: '0',
    );
  }

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  PackageInfo._({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });
}
