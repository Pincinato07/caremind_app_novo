import 'package:flutter/material.dart';
import '../../../services/exportacao_service.dart';
import '../../../core/injection/injection.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/errors/error_handler.dart';
import 'package:share_plus/share_plus.dart';

/// Tela de relatórios e exportação da organização
class RelatoriosOrganizacaoScreen extends StatefulWidget {
  final String organizacaoId;

  const RelatoriosOrganizacaoScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  State<RelatoriosOrganizacaoScreen> createState() =>
      _RelatoriosOrganizacaoScreenState();
}

class _RelatoriosOrganizacaoScreenState
    extends State<RelatoriosOrganizacaoScreen> {
  final ExportacaoService _exportacaoService = getIt<ExportacaoService>();
  bool _isExporting = false;

  Future<void> _exportarJSON() async {
    setState(() => _isExporting = true);
    try {
      final json = await _exportacaoService.exportarJSON(widget.organizacaoId);
      await Share.share(
        json,
        subject: 'Exportação Caremind - JSON',
      );
    } catch (e) {
      if (mounted) {
        FeedbackService.showError(context, ErrorHandler.toAppException(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportarCSV() async {
    setState(() => _isExporting = true);
    try {
      final csv = await _exportacaoService.exportarCSV(widget.organizacaoId);
      await Share.share(
        csv,
        subject: 'Exportação Caremind - CSV',
      );
    } catch (e) {
      if (mounted) {
        FeedbackService.showError(context, ErrorHandler.toAppException(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios e Exportação'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Exportação de Dados (LGPD)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Exporte todos os dados da organização em formato estruturado para conformidade com LGPD.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportarJSON,
              icon: const Icon(Icons.code),
              label: const Text('Exportar JSON'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportarCSV,
              icon: const Icon(Icons.table_chart),
              label: const Text('Exportar CSV'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
            ),
            if (_isExporting) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nota:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'A exportação inclui todos os dados: idosos, membros, medicamentos, rotinas e eventos dos últimos 90 dias. Em caso de cancelamento, você tem 30 dias para exportar os dados antes da exclusão permanente.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
