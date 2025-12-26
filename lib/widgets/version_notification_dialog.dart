import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_version.dart';

/// Diálogo de notificação para versões não-obrigatórias
class VersionNotificationDialog extends StatelessWidget {
  final AppVersion latestVersion;

  const VersionNotificationDialog({
    super.key,
    required this.latestVersion,
  });

  static Future<void> show(
    BuildContext context, {
    required AppVersion latestVersion,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => VersionNotificationDialog(latestVersion: latestVersion),
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

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.stars, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nova Versão Disponível!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versão ${latestVersion.versionName} está disponível',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (changelogLines.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'O que há de novo:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...changelogLines.take(5).map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line.trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Lembrar Depois'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await _launchDownloadUrl();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Baixar Agora'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
