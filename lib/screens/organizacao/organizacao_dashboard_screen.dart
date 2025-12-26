import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/organizacao_provider.dart';
import '../../widgets/organizacao/trial_blocked_guard.dart';
import 'membros/membros_lista_screen.dart';
import 'idosos/idosos_organizacao_lista_screen.dart';
import 'relatorios/relatorios_organizacao_screen.dart';
import 'analytics/analytics_organizacao_screen.dart';
import 'consolidado/consolidado_organizacao_screen.dart';
import 'organizacao_configuracoes_screen.dart';
import '../../services/analytics_organizacao_service.dart';
import '../../widgets/skeleton_dashboard_organizacao.dart';
import '../../widgets/wellbeing_checkin.dart';

/// Dashboard da organização
class OrganizacaoDashboardScreen extends ConsumerStatefulWidget {
  final String organizacaoId;

  const OrganizacaoDashboardScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  ConsumerState<OrganizacaoDashboardScreen> createState() =>
      _OrganizacaoDashboardScreenState();
}

class _OrganizacaoDashboardScreenState
    extends ConsumerState<OrganizacaoDashboardScreen> {
  final AnalyticsOrganizacaoService _analyticsService =
      AnalyticsOrganizacaoService();
  bool _loadingStats = false;
  int? _totalIdosos;
  int? _medicamentosPendentes;
  int? _eventosHoje;
  double? _taxaAdesao;

  @override
  void initState() {
    super.initState();
    _carregarEstatisticas();
  }

  Future<void> _carregarEstatisticas() async {
    setState(() => _loadingStats = true);
    try {
      final analytics = await _analyticsService.obterAnalyticsOrganizacao(
        widget.organizacaoId,
        dias: 30,
      );
      setState(() {
        _totalIdosos = analytics.totalIdosos;
        _medicamentosPendentes = analytics.medicamentosPendentes;
        _eventosHoje = analytics.eventosHoje;
        _taxaAdesao = analytics.taxaAdesaoGeral;
        _loadingStats = false;
      });
    } catch (e) {
      setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizacaoState = ref.watch(organizacaoProvider);
    final organizacao = organizacaoState.organizacaoAtual;

    if (organizacao == null || organizacao.id != widget.organizacaoId) {
      // Carregar organização se ainda não estiver carregada
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(organizacaoProvider.notifier)
            .selecionarOrganizacao(widget.organizacaoId);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return TrialBlockedGuard(
      child: Scaffold(
        appBar: AppBar(
          title: Text(organizacao.nome),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrganizacaoConfiguracoesScreen(
                      organizacaoId: widget.organizacaoId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de informações
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organizacao.nome,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (organizacao.cnpj != null) ...[
                        const SizedBox(height: 8),
                        Text('CNPJ: ${organizacao.cnpj}'),
                      ],
                      if (organizacao.telefone != null) ...[
                        const SizedBox(height: 4),
                        Text('Telefone: ${organizacao.telefone}'),
                      ],
                      if (organizacaoState.roleAtual != null) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            'Função: ${organizacaoState.roleAtual}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.blue.shade100,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Estatísticas Rápidas
              if (_loadingStats || _totalIdosos != null) ...[
                const Text(
                  'Estatísticas Rápidas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuickStats(context),
                const SizedBox(height: 24),
              ],
              // Bem-Estar dos Idosos
              const Text(
                'Bem-Estar dos Idosos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              WellbeingCheckin(
                perfilId: widget.organizacaoId,
                isReadOnly: true,
                isOrganizationView: true,
              ),
              const SizedBox(height: 24),
              // Ações rápidas
              const Text(
                'Ações Rápidas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final organizacaoNotifier = ref.read(organizacaoProvider.notifier);
                  final cards = <Widget>[];
                  
                  // Card Idosos - visível para quem pode gerenciar idosos
                  if (organizacaoNotifier.podeGerenciarIdosos()) {
                    cards.add(_buildActionCard(
                      context,
                      icon: Icons.people,
                      title: 'Idosos',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IdososOrganizacaoListaScreen(
                              organizacaoId: widget.organizacaoId,
                            ),
                          ),
                        );
                      },
                    ));
                  }
                  
                  // Card Membros - apenas para admins
                  if (organizacaoNotifier.podeGerenciarMembros()) {
                    cards.add(_buildActionCard(
                      context,
                      icon: Icons.group,
                      title: 'Membros',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MembrosListaScreen(
                              organizacaoId: widget.organizacaoId,
                            ),
                          ),
                        );
                      },
                    ));
                  }
                  
                  // Card Relatórios - visível para quem pode ver relatórios
                  if (organizacaoNotifier.podeVerRelatorios()) {
                    cards.add(_buildActionCard(
                      context,
                      icon: Icons.assessment,
                      title: 'Relatórios',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RelatoriosOrganizacaoScreen(
                              organizacaoId: widget.organizacaoId,
                            ),
                          ),
                        );
                      },
                    ));
                  }
                  
                  // Card Analytics - visível para quem pode ver analytics
                  if (organizacaoNotifier.podeVerAnalytics()) {
                    cards.add(_buildActionCard(
                      context,
                      icon: Icons.analytics,
                      title: 'Analytics',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalyticsOrganizacaoScreen(
                              organizacaoId: widget.organizacaoId,
                            ),
                          ),
                        );
                      },
                    ));
                  }
                  
                  // Card Visão Consolidada - visível para quem pode gerenciar idosos
                  if (organizacaoNotifier.podeGerenciarIdosos()) {
                    cards.add(_buildActionCard(
                      context,
                      icon: Icons.view_list,
                      title: 'Visão Consolidada',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConsolidadoOrganizacaoScreen(
                              organizacaoId: widget.organizacaoId,
                            ),
                          ),
                        );
                      },
                    ));
                  }
                  
                  // Card Configurações - apenas para admins
                  if (organizacaoNotifier.podeGerenciarConfiguracoes()) {
                    cards.add(_buildActionCard(
                      context,
                      icon: Icons.settings,
                      title: 'Configurações',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrganizacaoConfiguracoesScreen(
                              organizacaoId: widget.organizacaoId,
                            ),
                          ),
                        );
                      },
                    ));
                  }
                  
                  if (cards.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Você não tem permissão para acessar nenhuma funcionalidade.'),
                      ),
                    );
                  }
                  
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: cards,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    if (_loadingStats) {
      return const SkeletonDashboardOrganizacao();
    }

    if (_totalIdosos == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildQuickStatItem(
              'Idosos',
              _totalIdosos.toString(),
              Icons.people,
              Colors.blue,
            ),
            _buildQuickStatItem(
              'Pendentes',
              _medicamentosPendentes.toString(),
              Icons.medication,
              Colors.orange,
            ),
            _buildQuickStatItem(
              'Hoje',
              _eventosHoje.toString(),
              Icons.calendar_today,
              Colors.green,
            ),
            _buildQuickStatItem(
              'Adesão',
              _taxaAdesao != null
                  ? '${_taxaAdesao!.toStringAsFixed(0)}%'
                  : '0%',
              Icons.trending_up,
              _taxaAdesao != null && _taxaAdesao! >= 80
                  ? Colors.green
                  : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
