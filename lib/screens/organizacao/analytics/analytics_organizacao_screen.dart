import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/analytics_organizacao.dart';
import '../../../services/analytics_organizacao_service.dart';
import '../../../providers/organizacao_provider.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/errors/error_handler.dart';

/// Tela de Analytics da Organização
class AnalyticsOrganizacaoScreen extends ConsumerStatefulWidget {
  final String organizacaoId;

  const AnalyticsOrganizacaoScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  ConsumerState<AnalyticsOrganizacaoScreen> createState() =>
      _AnalyticsOrganizacaoScreenState();
}

class _AnalyticsOrganizacaoScreenState
    extends ConsumerState<AnalyticsOrganizacaoScreen> {
  final AnalyticsOrganizacaoService _analyticsService =
      AnalyticsOrganizacaoService();
  AnalyticsOrganizacao? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _carregarAnalytics();
  }

  Future<void> _carregarAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final analytics = await _analyticsService.obterAnalyticsOrganizacao(
        widget.organizacaoId,
        dias: 30,
      );
      setState(() {
        _analytics = analytics;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      if (mounted) {
        FeedbackService.showError(
            context, ErrorHandler.toAppException(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizacaoNotifier = ref.read(organizacaoProvider.notifier);
    final podeVer = organizacaoNotifier.podeVerAnalytics();
    
    if (!podeVer) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analytics da Organização'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Você não tem permissão para visualizar analytics. Entre em contato com o administrador da organização.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics da Organização'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarAnalytics,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erro ao carregar analytics: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _carregarAnalytics,
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                )
              : _analytics == null
                  ? const Center(child: Text('Nenhum dado disponível'))
                  : RefreshIndicator(
                      onRefresh: _carregarAnalytics,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Cards de Estatísticas
                            _buildStatsCards(),
                            const SizedBox(height: 24),
                            // Gráfico de Eventos por Dia
                            _buildEventosChart(),
                            const SizedBox(height: 24),
                            // Tabela de Adesão por Idoso
                            _buildAdesaoTable(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildStatsCards() {
    if (_analytics == null) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total de Idosos',
          _analytics!.totalIdosos.toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Medicamentos Pendentes',
          _analytics!.medicamentosPendentes.toString(),
          Icons.medication,
          Colors.orange,
        ),
        _buildStatCard(
          'Eventos Hoje',
          _analytics!.eventosHoje.toString(),
          Icons.calendar_today,
          Colors.green,
        ),
        _buildStatCard(
          'Taxa de Adesão',
          '${_analytics!.taxaAdesaoGeral.toStringAsFixed(1)}%',
          _analytics!.taxaAdesaoGeral >= 80
              ? Icons.trending_up
              : Icons.trending_down,
          _analytics!.taxaAdesaoGeral >= 80 ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventosChart() {
    if (_analytics == null || _analytics!.eventosPorDia.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhum evento nos últimos 30 dias'),
        ),
      );
    }

    final maxEventos = _analytics!.eventosPorDia
        .map((e) => e.total)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Eventos nos Últimos 30 Dias',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxEventos > 0 ? maxEventos.toDouble() : 10,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.grey.shade800,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() % 5 == 0) {
                            final index = value.toInt();
                            if (index >= 0 &&
                                index < _analytics!.eventosPorDia.length) {
                              final data = _analytics!.eventosPorDia[index].data;
                              final dia = DateTime.parse(data).day;
                              return Text(
                                dia.toString(),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _analytics!.eventosPorDia.asMap().entries.map((entry) {
                    final index = entry.key;
                    final evento = entry.value;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: evento.total.toDouble(),
                          color: Colors.blue,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: evento.total.toDouble(),
                            color: Colors.grey.shade200,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdesaoTable() {
    if (_analytics == null || _analytics!.adesaoPorIdoso.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhum dado de adesão disponível'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Taxa de Adesão por Idoso',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Idoso')),
                  DataColumn(label: Text('Eventos')),
                  DataColumn(label: Text('Concluídos')),
                  DataColumn(label: Text('Taxa')),
                  DataColumn(label: Text('Progresso')),
                ],
                rows: _analytics!.adesaoPorIdoso.map((item) {
                  final isGood = item.taxaAdesao >= 80;
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: Text(
                            item.idosoNome,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(item.totalEventos.toString())),
                      DataCell(Text(item.eventosConcluidos.toString())),
                      DataCell(
                        Text(
                          '${item.taxaAdesao.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: isGood ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(
                            value: item.taxaAdesao / 100,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isGood ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

