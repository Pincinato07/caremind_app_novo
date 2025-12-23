import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/exportacao_service.dart';
import '../../../services/idoso_organizacao_service.dart';
import '../../../services/organizacao_service.dart';
import '../../../providers/organizacao_provider.dart';
import '../../../core/injection/injection.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/errors/error_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'relatorio_visual_screen.dart';

/// Tela de relatórios e exportação da organização
class RelatoriosOrganizacaoScreen extends ConsumerStatefulWidget {
  final String organizacaoId;

  const RelatoriosOrganizacaoScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  ConsumerState<RelatoriosOrganizacaoScreen> createState() =>
      _RelatoriosOrganizacaoScreenState();
}

class _RelatoriosOrganizacaoScreenState
    extends ConsumerState<RelatoriosOrganizacaoScreen> {
  final ExportacaoService _exportacaoService = getIt<ExportacaoService>();
  final IdosoOrganizacaoService _idosoService = IdosoOrganizacaoService();
  bool _isExporting = false;
  
  // Filtros
  String _periodoSelecionado = '30dias'; // '7dias', '30dias', '90dias', 'customizado'
  String? _idosoSelecionado;
  String _tipoSelecionado = 'todos'; // 'todos', 'medicamentos', 'rotinas', 'compromissos'
  DateTime? _dataInicio;
  DateTime? _dataFim;
  List<IdosoOrganizacao> _idosos = [];
  
  @override
  void initState() {
    super.initState();
    _carregarIdosos();
  }
  
  Future<void> _carregarIdosos() async {
    try {
      final idosos = await _idosoService.listarIdosos(widget.organizacaoId);
      setState(() => _idosos = idosos);
    } catch (e) {
      // Ignorar erro silenciosamente
    }
  }

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
    final organizacaoNotifier = ref.read(organizacaoProvider.notifier);
    final podeExportar = organizacaoNotifier.podeExportarDados();
    
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
              'Relatórios e Exportação',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure filtros e exporte dados da organização em formato estruturado para conformidade com LGPD.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // Botão para Relatórios Visuais
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RelatorioVisualScreen(
                      organizacaoId: widget.organizacaoId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('Ver Relatórios Visuais'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            // Filtros
            _buildFiltrosSection(),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            const Text(
              'Exportação de Dados (LGPD)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Exporte os dados filtrados em formato estruturado.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (podeExportar) ...[
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
            ] else ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Você não tem permissão para exportar dados. Entre em contato com o administrador da organização.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
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
  
  Widget _buildFiltrosSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Filtro de Período
            DropdownButtonFormField<String>(
              value: _periodoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Período',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '7dias', child: Text('Últimos 7 dias')),
                DropdownMenuItem(value: '30dias', child: Text('Últimos 30 dias')),
                DropdownMenuItem(value: '90dias', child: Text('Últimos 90 dias')),
                DropdownMenuItem(value: 'customizado', child: Text('Personalizado')),
              ],
              onChanged: (value) {
                setState(() {
                  _periodoSelecionado = value ?? '30dias';
                  if (_periodoSelecionado != 'customizado') {
                    _dataInicio = null;
                    _dataFim = null;
                  }
                });
                if (_periodoSelecionado == 'customizado') {
                  _selecionarPeriodoCustomizado();
                }
              },
            ),
            const SizedBox(height: 16),
            // Filtro de Idoso
            DropdownButtonFormField<String>(
              value: _idosoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Idoso',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos os idosos'),
                ),
                ..._idosos.map((idoso) => DropdownMenuItem<String>(
                      value: idoso.perfilId,
                      child: Text(idoso.nomePerfil ?? 'Sem nome'),
                    )).toList(),
              ],
              onChanged: (value) {
                setState(() => _idosoSelecionado = value);
              },
            ),
            const SizedBox(height: 16),
            // Filtro de Tipo
            DropdownButtonFormField<String>(
              value: _tipoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'todos', child: Text('Todos')),
                DropdownMenuItem(value: 'medicamentos', child: Text('Medicamentos')),
                DropdownMenuItem(value: 'rotinas', child: Text('Rotinas')),
                DropdownMenuItem(value: 'compromissos', child: Text('Compromissos')),
              ],
              onChanged: (value) {
                setState(() => _tipoSelecionado = value ?? 'todos');
              },
            ),
            if (_periodoSelecionado == 'customizado' && _dataInicio != null && _dataFim != null) ...[
              const SizedBox(height: 16),
              Text(
                'Período: ${DateFormat('dd/MM/yyyy').format(_dataInicio!)} - ${DateFormat('dd/MM/yyyy').format(_dataFim!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _selecionarPeriodoCustomizado() async {
    final hoje = DateTime.now();
    final dataInicio = await showDatePicker(
      context: context,
      initialDate: hoje.subtract(const Duration(days: 30)),
      firstDate: hoje.subtract(const Duration(days: 365)),
      lastDate: hoje,
    );
    
    if (dataInicio != null) {
      final dataFim = await showDatePicker(
        context: context,
        initialDate: dataInicio.isBefore(hoje) ? dataInicio : hoje,
        firstDate: dataInicio,
        lastDate: hoje,
      );
      
      if (dataFim != null) {
        setState(() {
          _dataInicio = dataInicio;
          _dataFim = dataFim;
        });
      }
    }
  }
}
