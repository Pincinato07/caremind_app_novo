import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/analytics_organizacao_service.dart';
import '../../../providers/organizacao_provider.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/errors/error_handler.dart';

/// Tela de Relatórios Visuais da Organização
class RelatorioVisualScreen extends ConsumerStatefulWidget {
  final String organizacaoId;

  const RelatorioVisualScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  ConsumerState<RelatorioVisualScreen> createState() =>
      _RelatorioVisualScreenState();
}

class _RelatorioVisualScreenState
    extends ConsumerState<RelatorioVisualScreen> {
  final AnalyticsOrganizacaoService _analyticsService =
      AnalyticsOrganizacaoService();

  bool _loading = true;
  String? _error;
  String _tipoGrafico = 'eventos'; // 'eventos', 'adesao', 'medicamentos'

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Carregar analytics para gráficos
      await _analyticsService.obterAnalyticsOrganizacao(
        widget.organizacaoId,
        dias: 30,
      );
      setState(() => _loading = false);
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
    final podeVer = organizacaoNotifier.podeVerRelatorios();

    if (!podeVer) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Relatórios Visuais'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Você não tem permissão para visualizar relatórios. Entre em contato com o administrador da organização.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios Visuais'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _tipoGrafico = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'eventos',
                child: Text('Eventos ao Longo do Tempo'),
              ),
              const PopupMenuItem(
                value: 'adesao',
                child: Text('Taxa de Adesão'),
              ),
              const PopupMenuItem(
                value: 'medicamentos',
                child: Text('Distribuição de Medicamentos'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
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
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erro ao carregar dados: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _carregarDados,
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregarDados,
                  child: FutureBuilder(
                    future: _analyticsService.obterAnalyticsOrganizacao(
                      widget.organizacaoId,
                      dias: 30,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError || !snapshot.hasData) {
                        return Center(
                          child: Text('Erro: ${snapshot.error}'),
                        );
                      }

                      final analytics = snapshot.data!;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_tipoGrafico == 'eventos')
                              _buildEventosLineChart(analytics),
                            if (_tipoGrafico == 'adesao')
                              _buildAdesaoChart(analytics),
                            if (_tipoGrafico == 'medicamentos')
                              _buildMedicamentosChart(analytics),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEventosLineChart(analytics) {
    final eventosPorDia = analytics.eventosPorDia;
    if (eventosPorDia.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhum evento nos últimos 30 dias'),
        ),
      );
    }

    final maxEventos = eventosPorDia
        .map((e) => e.total)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Eventos ao Longo do Tempo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() % 5 == 0) {
                            final index = value.toInt();
                            if (index >= 0 && index < eventosPorDia.length) {
                              final data = eventosPorDia[index].data;
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
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: eventosPorDia.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.total.toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                    LineChartBarData(
                      spots: eventosPorDia.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.concluidos.toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  minY: 0,
                  maxY: maxEventos > 0 ? maxEventos.toDouble() : 10,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Total', Colors.blue),
                const SizedBox(width: 16),
                _buildLegendItem('Concluídos', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdesaoChart(analytics) {
    final adesaoPorIdoso = analytics.adesaoPorIdoso;
    if (adesaoPorIdoso.isEmpty) {
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
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < adesaoPorIdoso.length) {
                            final nome = adesaoPorIdoso[index].idosoNome;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                nome.length > 10
                                    ? '${nome.substring(0, 10)}...'
                                    : nome,
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 50,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barGroups: adesaoPorIdoso.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isGood = item.taxaAdesao >= 80;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: item.taxaAdesao,
                          color: isGood ? Colors.green : Colors.orange,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
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

  Widget _buildMedicamentosChart(analytics) {
    final medicamentosStats = analytics.medicamentosStats;
    if (medicamentosStats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhum dado de medicamentos disponível'),
        ),
      );
    }

    final totalPendentes = medicamentosStats
        .map((m) => m.medicamentosPendentes)
        .fold(0, (a, b) => a + b);
    final totalAtrasados = medicamentosStats
        .map((m) => m.medicamentosAtrasados)
        .fold(0, (a, b) => a + b);
    final totalConcluidos = totalPendentes - totalAtrasados;

    return Column(
      children: [
        // Gráfico de Pizza - Distribuição de Status
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribuição de Status de Medicamentos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: [
                        PieChartSectionData(
                          value: totalConcluidos.toDouble(),
                          color: Colors.green,
                          title: 'Concluídos',
                          radius: 50,
                        ),
                        PieChartSectionData(
                          value: totalAtrasados.toDouble(),
                          color: Colors.red,
                          title: 'Atrasados',
                          radius: 50,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('Concluídos', Colors.green),
                    const SizedBox(width: 16),
                    _buildLegendItem('Atrasados', Colors.red),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Gráfico de Barras Comparativo
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medicamentos por Idoso',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: medicamentosStats
                              .map((m) => m.totalMedicamentos)
                              .reduce((a, b) => a > b ? a : b)
                          .toDouble(),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 &&
                                  index < medicamentosStats.length) {
                                final nome =
                                    medicamentosStats[index].idosoNome;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    nome.length > 10
                                        ? '${nome.substring(0, 10)}...'
                                        : nome,
                                    style: const TextStyle(fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 50,
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
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barGroups: medicamentosStats.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: item.totalMedicamentos.toDouble(),
                              color: Colors.blue,
                              width: 16,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
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
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

