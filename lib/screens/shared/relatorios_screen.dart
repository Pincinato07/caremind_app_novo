import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/relatorios_service.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';
import '../../core/state/familiar_state.dart';
import '../../core/errors/app_exception.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/banner_contexto_familiar.dart';

class RelatoriosScreen extends StatefulWidget {
  final bool embedded; // Se true, não mostra AppScaffoldWithWaves

  const RelatoriosScreen({super.key, this.embedded = false});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  final RelatoriosService _relatoriosService = getIt<RelatoriosService>();
  final SupabaseService _supabaseService = getIt<SupabaseService>();
  final FamiliarState _familiarState = getIt<FamiliarState>();

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _analyticsData;
  List<dynamic>? _eventosList;

  DateTime _dataInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dataFim = DateTime.now();
  String? _perfilId;

  @override
  void initState() {
    super.initState();
    _loadPerfilId();
    _loadRelatorios();
  }

  Future<void> _loadPerfilId() async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) return;

      // Se for familiar, usar o idoso selecionado
      if (_familiarState.hasIdosos && _familiarState.idosoSelecionado != null) {
        setState(() {
          _perfilId = _familiarState.idosoSelecionado!.id;
        });
      } else {
        // Caso contrário, usar o próprio perfil
        final perfil = await _supabaseService.getProfile(user.id);
        if (perfil != null) {
          setState(() {
            _perfilId = perfil.id;
          });
        }
      }
    } catch (e) {
      // Erro silencioso
    }
  }

  Future<void> _loadRelatorios() async {
    if (_perfilId == null) {
      await _loadPerfilId();
      if (_perfilId == null) {
        setState(() {
          _error = 'Perfil não encontrado';
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dataInicioISO = DateFormat('yyyy-MM-dd').format(_dataInicio);
      final dataFimISO = DateFormat('yyyy-MM-dd').format(_dataFim);

      // Buscar dados analíticos
      final analytics = await _relatoriosService.getRelatorioHistorico(
        perfilId: _perfilId!,
        dataInicio: dataInicioISO,
        dataFim: dataFimISO,
        mode: 'analytics',
      );

      // Buscar lista de eventos
      final eventosResponse = await _relatoriosService.getRelatorioHistorico(
        perfilId: _perfilId!,
        dataInicio: dataInicioISO,
        dataFim: dataFimISO,
        mode: 'list',
      );

      setState(() {
        _analyticsData = analytics;
        // A resposta em modo 'list' retorna um Map com 'data' contendo a lista
        if (eventosResponse.containsKey('data')) {
          final data = eventosResponse['data'];
          _eventosList = data is List ? data : null;
        } else {
          _eventosList = null;
        }
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = error is AppException
            ? error.message
            : 'Erro ao carregar relatórios: ${error.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _dataInicio, end: _dataFim),
      helpText: 'Selecione o período',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF0400BA),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dataInicio = picked.start;
        _dataFim = picked.end;
      });
      _loadRelatorios();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFamiliar = _familiarState.hasIdosos;

    final content = SafeArea(
      child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadRelatorios,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0400BA),
                          ),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  )
                : _analyticsData == null
                    ? const Center(
                        child: Text(
                          'Nenhum dado disponível',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Banner de contexto para perfil familiar
                            if (isFamiliar)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: BannerContextoFamiliar(),
                              ),

                            // Seletor de período
                            GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Período',
                                          style: AppTextStyles.leagueSpartan(
                                            fontSize: 14,
                                            color: Colors.white.withValues(alpha: 0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${DateFormat('dd/MM/yyyy').format(_dataInicio)} - ${DateFormat('dd/MM/yyyy').format(_dataFim)}',
                                          style: AppTextStyles.leagueSpartan(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.white),
                                    onPressed: _selectDateRange,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // KPIs
                            _buildKPISection(_analyticsData!['kpis'] as Map<String, dynamic>? ?? {}),

                            const SizedBox(height: 24),

                            // Gráficos
                            _buildChartsSection(_analyticsData!['graficos'] as Map<String, dynamic>? ?? {}),

                            const SizedBox(height: 24),

                            // Tabela de eventos
                            if (_eventosList != null && _eventosList!.isNotEmpty)
                              _buildEventosTable(_eventosList!),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
    );

    if (widget.embedded) {
      // Modo embedded: retorna apenas o conteúdo, sem AppScaffoldWithWaves
      return content;
    }

    // Modo standalone: retorna com AppScaffoldWithWaves
    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: 'Relatórios',
        isFamiliar: isFamiliar,
      ),
      body: content,
    );
  }

  Widget _buildKPISection(Map<String, dynamic> kpis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Indicadores Principais',
          style: AppTextStyles.leagueSpartan(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildKPICard(
              'Taxa de Adesão',
              '${(kpis['taxa_adesao_total'] as num? ?? 0).toStringAsFixed(1)}%',
              Icons.check_circle,
              Colors.green,
            ),
            _buildKPICard(
              'Total de Eventos',
              '${kpis['total_eventos'] ?? 0}',
              Icons.event,
              const Color(0xFF0400BA),
            ),
            _buildKPICard(
              'Confirmados',
              '${kpis['total_confirmados'] ?? 0}',
              Icons.done_all,
              Colors.blue,
            ),
            _buildKPICard(
              'Esquecidos',
              '${kpis['total_esquecidos'] ?? 0}',
              Icons.warning,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.leagueSpartan(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.leagueSpartan(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(Map<String, dynamic> graficos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Análises Gráficas',
          style: AppTextStyles.leagueSpartan(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Gráfico de Tendência Diária
        if (graficos['tendencia_diaria'] != null)
          _buildTendenciaDiariaChart(
            graficos['tendencia_diaria'] as List<dynamic>,
          ),

        const SizedBox(height: 24),

        // Gráfico de Performance por Turnos
        if (graficos['performance_turnos'] != null)
          _buildPerformanceTurnosChart(
            graficos['performance_turnos'] as Map<String, dynamic>,
          ),

        const SizedBox(height: 24),

        // Resumo por Tipo
        if (graficos['resumo_por_tipo'] != null)
          _buildResumoPorTipoChart(
            graficos['resumo_por_tipo'] as Map<String, dynamic>,
          ),
      ],
    );
  }

  Widget _buildTendenciaDiariaChart(List<dynamic> tendencia) {
    if (tendencia.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendência Diária de Adesão',
            style: AppTextStyles.leagueSpartan(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= tendencia.length) return const Text('');
                        final data = tendencia[value.toInt()]['data'] as String;
                        return Text(
                          DateFormat('dd/MM').format(DateTime.parse(data)),
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: tendencia.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value as Map<String, dynamic>;
                      final percentual = item['percentual'] as num? ?? 0;
                      return FlSpot(index.toDouble(), percentual.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: Colors.white,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF0400BA),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTurnosChart(Map<String, dynamic> turnos) {
    final turnosList = [
      {'nome': 'Manhã', 'data': turnos['manha'] ?? {}},
      {'nome': 'Tarde', 'data': turnos['tarde'] ?? {}},
      {'nome': 'Noite', 'data': turnos['noite'] ?? {}},
    ];

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance por Turno',
            style: AppTextStyles.leagueSpartan(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ...turnosList.map((turno) {
            final data = turno['data'] as Map<String, dynamic>;
            final percentual = (data['percentual'] as num? ?? 0).toDouble();
            final total = data['total'] as int? ?? 0;
            final confirmados = data['confirmados'] as int? ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        turno['nome'] as String,
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${percentual.toStringAsFixed(1)}%',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentual / 100,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentual >= 80
                            ? Colors.green
                            : percentual >= 50
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$confirmados de $total eventos',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildResumoPorTipoChart(Map<String, dynamic> resumo) {
    final tipos = [
      {'nome': 'Medicamentos', 'key': 'medicamento'},
      {'nome': 'Rotinas', 'key': 'rotina'},
      {'nome': 'Outros', 'key': 'outros'},
    ];

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo por Tipo',
            style: AppTextStyles.leagueSpartan(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ...tipos.map((tipo) {
            final data = resumo[tipo['key']] as Map<String, dynamic>? ?? {};
            final percentual = (data['percentual'] as num? ?? 0).toDouble();
            final total = data['total'] as int? ?? 0;
            final confirmados = data['confirmados'] as int? ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tipo['nome'] as String,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$confirmados de $total',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${percentual.toStringAsFixed(0)}%',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEventosTable(List<dynamic> eventos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Histórico de Eventos',
          style: AppTextStyles.leagueSpartan(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: eventos.take(20).map((evento) {
              final data = evento as Map<String, dynamic>;
              final dataPrevista = data['data_prevista'] as String?;
              final status = (data['status'] as String? ?? '').toLowerCase();
              final tipoEvento = (data['tipo_evento'] as String? ?? '').toLowerCase();

              Color statusColor;
              IconData statusIcon;
              switch (status) {
                case 'confirmado':
                case 'realizado':
                case 'tomado':
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle;
                  break;
                case 'atrasado':
                case 'pendente':
                  statusColor = Colors.orange;
                  statusIcon = Icons.schedule;
                  break;
                default:
                  statusColor = Colors.red;
                  statusIcon = Icons.cancel;
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tipoEvento.toUpperCase(),
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (dataPrevista != null)
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(
                                DateTime.parse(dataPrevista),
                              ),
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      status.toUpperCase(),
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

