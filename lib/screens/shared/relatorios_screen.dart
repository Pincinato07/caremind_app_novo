import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../../services/relatorios_service.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';
import '../../core/state/familiar_state.dart';
import '../../core/errors/app_exception.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
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
        if (mounted) {
          setState(() {
            _error = 'Perfil não encontrado';
            _isLoading = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

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

      if (mounted) {
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
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AppException
              ? error.message
              : 'Erro ao carregar relatórios: ${error.toString()}';
          _isLoading = false;
        });
      }
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

    if (picked != null && mounted) {
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

    final Widget content;
    if (_isLoading) {
      content = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else if (_error != null) {
      content = Center(
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
      );
    } else if (_analyticsData == null) {
      content = const Center(
        child: Text(
          'Nenhum dado disponível',
          style: TextStyle(color: Colors.white),
        ),
      );
    } else {
      content = SingleChildScrollView(
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
            AnimatedCard(
              index: 0,
              child: CareMindCard(
                variant: CardVariant.glass,
                padding: AppSpacing.paddingCard,
                child: Row(
                  children: [
                    const Icon(
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
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
            ),

            SizedBox(height: AppSpacing.large),

            // KPIs
            _buildKPISection(
                _analyticsData!['kpis'] as Map<String, dynamic>? ?? {}),

            const SizedBox(height: 24),

            // Gráficos
            _buildChartsSection(
                _analyticsData!['graficos'] as Map<String, dynamic>? ?? {}),

            const SizedBox(height: 24),

            // Tabela de eventos
            if (_eventosList != null && _eventosList!.isNotEmpty)
              _buildEventosTable(_eventosList!),

            SizedBox(height: AppSpacing.bottomNavBarPadding),
          ],
        ),
      );
    }

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
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Resumo do Período',
              style: AppTextStyles.leagueSpartan(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Visão geral da adesão aos medicamentos e rotinas',
          style: AppTextStyles.leagueSpartan(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 20),
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
              'Porcentagem geral de medicamentos tomados corretamente',
            ),
            _buildKPICard(
              'Total de Eventos',
              '${kpis['total_eventos'] ?? 0}',
              Icons.event,
              const Color(0xFF0400BA),
              'Todos os medicamentos e rotinas programados',
            ),
            _buildKPICard(
              'Confirmados',
              '${kpis['total_confirmados'] ?? 0}',
              Icons.done_all,
              Colors.blue,
              'Medicamentos e rotinas realizados conforme esperado',
            ),
            _buildKPICard(
              'Esquecidos',
              '${kpis['total_esquecidos'] ?? 0}',
              Icons.warning,
              Colors.orange,
              'Medicamentos ou rotinas não realizados',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color,
      String description) {
    return AnimatedCard(
      index: 1,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: AppSpacing.paddingCard,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTextStyles.leagueSpartan(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTextStyles.leagueSpartan(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.leagueSpartan(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(Map<String, dynamic> graficos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.insert_chart_outlined,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Análises Detalhadas',
              style: AppTextStyles.leagueSpartan(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Gráficos e tendências para entender melhor o padrão de adesão',
          style: AppTextStyles.leagueSpartan(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 20),

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

    return AnimatedCard(
      index: 2,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Evolução da Adesão',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Gráfico de linha simulado
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Gráfico de evolução\n(em desenvolvimento)',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTurnosChart(Map<String, dynamic> turnos) {
    final turnosList = [
      {'nome': 'Manhã', 'key': 'manha'},
      {'nome': 'Tarde', 'key': 'tarde'},
      {'nome': 'Noite', 'key': 'noite'},
    ];

    return AnimatedCard(
      index: 3,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Adesão por Turno',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...turnosList.map((turno) {
              final data = turnos[turno['key']] as Map<String, dynamic>? ?? {};
              final percentual = (data['percentual'] as num? ?? 0).toDouble();
              final total = data['total'] as int? ?? 0;
              final confirmados = data['confirmados'] as int? ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            turno['nome'] as String,
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$confirmados realizados de $total',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
      ),
    );
  }

  Widget _buildResumoPorTipoChart(Map<String, dynamic> resumo) {
    final tipos = [
      {'nome': 'Medicamentos', 'key': 'medicamento'},
      {'nome': 'Rotinas', 'key': 'rotina'},
      {'nome': 'Outros', 'key': 'outros'},
    ];

    return AnimatedCard(
      index: 4,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Distribuição por Categoria',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
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
                      flex: 2,
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
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$confirmados realizados de $total',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
      ),
    );
  }

  Widget _buildEventosTable(List<dynamic> eventos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Histórico Detalhado',
              style: AppTextStyles.leagueSpartan(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Lista dos últimos eventos com seus status e detalhes',
          style: AppTextStyles.leagueSpartan(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        SizedBox(height: AppSpacing.medium + 4),
        AnimatedCard(
          index: 5,
          child: CareMindCard(
            variant: CardVariant.glass,
            padding: EdgeInsets.zero,
            child: Column(
              children: eventos.take(20).map((evento) {
                final data = evento as Map<String, dynamic>;
                final dataPrevista = data['data_prevista'] as String?;
                final status = data['status'] as String? ?? 'pendente';

                Color statusColor = Colors.grey;
                IconData statusIcon = Icons.help_outline;
                String statusText = 'Pendente';

                switch (status.toLowerCase()) {
                  case 'confirmado':
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                    statusText = 'Confirmado';
                    break;
                  case 'atrasado':
                    statusColor = Colors.red;
                    statusIcon = Icons.warning;
                    statusText = 'Atrasado';
                    break;
                  case 'pendente':
                    statusColor = Colors.orange;
                    statusIcon = Icons.schedule;
                    statusText = 'Pendente';
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          statusIcon,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['titulo'] as String? ?? 'Evento',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            if (dataPrevista != null)
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm')
                                    .format(DateTime.parse(dataPrevista)),
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
