// lib/screens/shared/alertas_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../core/state/familiar_state.dart';
import '../../core/injection/injection.dart';
import '../../services/notificacoes_app_service.dart';
import '../../models/notificacao_app.dart';
import 'relatorios_screen.dart';

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FamiliarState _familiarState = getIt<FamiliarState>();

  @override
  void initState() {
    super.initState();
    // Iniciar na aba de Relatórios (índice 1)
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFamiliar = _familiarState.hasIdosos;
    
    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: 'Relatórios',
        isFamiliar: isFamiliar,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8), // Padding top
          // Botão de marcar todas como lidas
          StreamBuilder<int>(
            stream: getIt<NotificacoesAppService>().countNaoLidasStream,
            initialData: getIt<NotificacoesAppService>().countNaoLidas,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextButton.icon(
                    onPressed: () async {
                      final service = getIt<NotificacoesAppService>();
                      final marcadas = await service.marcarTodasComoLidas();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$marcadas notificações marcadas como lidas'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.done_all, color: Colors.white),
                    label: Text(
                      'Marcar todas como lidas ($count)',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
              labelStyle: AppTextStyles.leagueSpartan(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: AppTextStyles.leagueSpartan(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications),
                      SizedBox(width: 8),
                      Text('Notificações'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics),
                      SizedBox(width: 8),
                      Text('Relatórios'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _NotificacoesTab(),
                RelatoriosScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificacoesTab extends StatefulWidget {
  const _NotificacoesTab();

  @override
  State<_NotificacoesTab> createState() => _NotificacoesTabState();
}

class _NotificacoesTabState extends State<_NotificacoesTab> {
  final NotificacoesAppService _service = getIt<NotificacoesAppService>();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotificacoes();
  }

  Future<void> _loadNotificacoes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _service.initialize();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getColorForTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'medicamento':
        return const Color(0xFF8B5CF6);
      case 'rotina':
        return const Color(0xFF3B82F6);
      case 'compromisso':
        return const Color(0xFF06B6D4);
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_outline;
      case 'medicamento':
        return Icons.medication_liquid;
      case 'rotina':
        return Icons.schedule_rounded;
      case 'compromisso':
        return Icons.calendar_today;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatarDataHoraCompleta(DateTime dataHora) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dataHora);
  }

  Future<void> _marcarComoLida(NotificacaoApp notificacao) async {
    if (notificacao.lida) return;
    
    try {
      await _service.marcarComoLida(notificacao.id);
    } catch (e) {
      debugPrint('Erro ao marcar como lida: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar notificações',
              style: AppTextStyles.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.leagueSpartan(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNotificacoes,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<NotificacaoApp>>(
      stream: _service.notificacoesStream,
      initialData: _service.notificacoes,
      builder: (context, snapshot) {
        final notificacoes = snapshot.data ?? [];

        if (notificacoes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma notificação',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Tudo está em ordem! Não há notificações no momento.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadNotificacoes,
          backgroundColor: Colors.white,
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: notificacoes.length,
            itemBuilder: (context, index) {
              final notificacao = notificacoes[index];
              final color = _getColorForTipo(notificacao.tipo);
              final icon = _getIconForTipo(notificacao.tipo);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () => _marcarComoLida(notificacao),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: notificacao.lida ? 0.7 : 1.0,
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      borderColor: notificacao.lida 
                          ? Colors.white.withValues(alpha: 0.1)
                          : color.withValues(alpha: 0.5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ícone colorido com indicador de não lida
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              // Indicador de não lida
                              if (!notificacao.lida)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Conteúdo
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título com badge de prioridade
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notificacao.titulo,
                                        style: AppTextStyles.leagueSpartan(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (notificacao.isUrgente)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'URGENTE',
                                          style: AppTextStyles.leagueSpartan(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    else if (notificacao.isAlta)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'ALTA',
                                          style: AppTextStyles.leagueSpartan(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Mensagem
                                Text(
                                  notificacao.mensagem,
                                  style: AppTextStyles.leagueSpartan(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Data/Hora e tempo relativo
                                Row(
                                  children: [
                                    Text(
                                      _formatarDataHoraCompleta(notificacao.dataCriacao),
                                      style: AppTextStyles.leagueSpartan(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      notificacao.tempoRelativo,
                                      style: AppTextStyles.leagueSpartan(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
