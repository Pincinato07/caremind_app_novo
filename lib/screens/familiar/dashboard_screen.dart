import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/historico_eventos_service.dart';
import '../../core/injection/injection.dart';
import '../../core/state/familiar_state.dart';
import '../../models/medicamento.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/caremind_card.dart';
import '../../core/accessibility/accessibility_helper.dart';
import '../../widgets/charts/adherence_bar_chart.dart';
import '../../widgets/charts/adherence_line_chart.dart';
import '../../widgets/skeleton_loader.dart';

/// Dashboard do FAMILIAR/CUIDADOR
/// Objetivo: Tranquilidade. O familiar quer saber: "Está tudo bem?"
/// Diretriz Visual: Dashboard informativo, listas densas, status coloridos (Verde/Vermelho).
class FamiliarDashboardScreen extends StatefulWidget {
  const FamiliarDashboardScreen({super.key});

  @override
  State<FamiliarDashboardScreen> createState() => _FamiliarDashboardScreenState();
}

class _FamiliarDashboardScreenState extends State<FamiliarDashboardScreen> {
  String _userName = 'Familiar';
  bool _isLoading = true;
  Map<String, dynamic> _statusIdosos = {};
  
  List<Map<String, dynamic>> _alertas = [];
  DateTime? _ultimaAtividade;
  List<DailyAdherence> _dadosAdesao = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    // Escutar mudanças no FamiliarState
    final familiarState = getIt<FamiliarState>();
    familiarState.addListener(_onFamiliarStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Leitura automática do título da tela se habilitada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityHelper.autoReadIfEnabled('Dashboard Familiar. Olá, $_userName');
    });
  }

  @override
  void dispose() {
    final familiarState = getIt<FamiliarState>();
    familiarState.removeListener(_onFamiliarStateChanged);
    super.dispose();
  }

  void _onFamiliarStateChanged() {
    // Recarregar status quando o idoso selecionado mudar
    final familiarState = getIt<FamiliarState>();
    if (mounted && familiarState.idosoSelecionado != null) {
      _carregarStatusIdoso(familiarState.idosoSelecionado!.id);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      if (supabaseService == null) {
        throw Exception('SupabaseService não disponível');
      }
      
      final familiarState = getIt<FamiliarState>();
      if (familiarState == null) {
        throw Exception('FamiliarState não disponível');
      }
      
      final user = supabaseService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        debugPrint('⚠️ Usuário não autenticado');
        return;
      }
      
      if (user.id.isEmpty) {
        throw Exception('ID de usuário inválido');
      }
      
      final perfil = await supabaseService.getProfile(user.id);
      if (perfil == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        debugPrint('⚠️ Perfil não encontrado');
        return;
      }
      
      if (!mounted) return;
      
      // Carregar idosos no FamiliarState (já deve estar carregado pelo shell, mas garantir)
      try {
        if (!familiarState.hasIdosos) {
          await familiarState.carregarIdosos(user.id);
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar idosos: $e');
        // Continuar mesmo se falhar
      }
      
      // Carregar status do idoso selecionado
      if (familiarState.idosoSelecionado != null) {
        try {
          await _carregarStatusIdoso(familiarState.idosoSelecionado!.id);
        } catch (e) {
          debugPrint('⚠️ Erro ao carregar status do idoso: $e');
          // Continuar mesmo se falhar
        }
      }

      if (mounted) {
        setState(() {
          _userName = perfil.nome ?? 'Familiar';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao carregar dados do usuário: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Mostrar erro apenas se for crítico
        if (e.toString().contains('network') || 
            e.toString().contains('connection') ||
            e.toString().contains('timeout')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro de conexão. Verifique sua internet.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Tentar novamente',
                textColor: Colors.white,
                onPressed: _loadUserData,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _carregarStatusIdoso(String idosoId) async {
    if (idosoId.isEmpty) {
      debugPrint('⚠️ ID do idoso vazio');
      return;
    }
    
    try {
      final familiarState = getIt<FamiliarState>();
      final supabaseService = getIt<SupabaseService>();
      final medicamentoService = getIt<MedicamentoService>();
      
      // Carregar medicamentos
      List<Medicamento> medicamentos = [];
      try {
        medicamentos = await medicamentoService.getMedicamentos(idosoId);
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar medicamentos: $e');
        medicamentos = []; // Continuar com lista vazia
      }
      
      // Carregar última atividade (updated_at do perfil)
      try {
        final perfilIdoso = await supabaseService.getProfile(idosoId);
        if (perfilIdoso != null) {
          _ultimaAtividade = perfilIdoso.createdAt; // Usar createdAt como fallback
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar perfil do idoso: $e');
        // Continuar sem última atividade
      }
      
      // Verificar status de medicamentos concluídos hoje
      Map<int, bool> statusMedicamentos = {};
      if (medicamentos.isNotEmpty) {
        try {
          final ids = medicamentos
              .where((m) => m.id != null)
              .map((m) => m.id!)
              .where((id) => id > 0)
              .toList();
          
          if (ids.isNotEmpty) {
            statusMedicamentos = await HistoricoEventosService.checkMedicamentosConcluidosHoje(idosoId, ids);
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao verificar status de medicamentos: $e');
          // Continuar com mapa vazio
        }
      }
      
      // Gerar alertas baseados em medicamentos atrasados
      try {
        _alertas = _gerarAlertas(medicamentos, statusMedicamentos);
      } catch (e) {
        debugPrint('⚠️ Erro ao gerar alertas: $e');
        _alertas = []; // Continuar sem alertas
      }
      
      // Buscar dados de adesão dos últimos 7 dias
      try {
        _dadosAdesao = await HistoricoEventosService.getDadosAdesaoUltimos7Dias(idosoId);
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar dados de adesão: $e');
        _dadosAdesao = []; // Continuar sem dados de adesão
      }
      
      final pendentes = medicamentos.where((m) => !(statusMedicamentos[m.id] ?? false)).toList();
      final tomados = medicamentos.where((m) => statusMedicamentos[m.id] ?? false).toList();
      
      final temAtraso = pendentes.isNotEmpty;
      final idosoNome = familiarState.idosoSelecionado?.nome ?? 'Idoso';
      final mensagemStatus = pendentes.isEmpty
          ? '$idosoNome tomou tudo hoje.'
          : '$idosoNome tem ${pendentes.length} medicamento(s) pendente(s).';

      if (mounted) {
        setState(() {
          _statusIdosos[idosoId] = {
            'temAtraso': temAtraso,
            'mensagem': mensagemStatus,
            'totalPendentes': pendentes.length,
            'total': medicamentos.length,
            'tomados': tomados.length,
          };
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao carregar status do idoso: $e');
      debugPrint('Stack trace: $stackTrace');
      // Não mostrar erro ao usuário, apenas log
    }
  }

  List<Map<String, dynamic>> _gerarAlertas(
    List<Medicamento> medicamentos, 
    Map<int, bool> statusMedicamentos
  ) {
    try {
      final alertas = <Map<String, dynamic>>[];
      final agora = DateTime.now();
      
      if (medicamentos.isEmpty) {
        return alertas;
      }
      
      for (var med in medicamentos) {
        try {
          if (statusMedicamentos[med.id] ?? false) continue;
          
          // Verificar se há horários passados hoje
          try {
            final horarios = _extrairHorarios(med);
            for (var horario in horarios) {
              try {
                final horarioDateTime = DateTime(
                  agora.year,
                  agora.month,
                  agora.day,
                  horario.hour,
                  horario.minute,
                );
                
                if (horarioDateTime.isBefore(agora)) {
                  final nomeMed = med.nome ?? 'Medicamento';
                  alertas.add({
                    'tipo': 'atraso',
                    'mensagem': '$nomeMed Atrasado',
                    'horario': '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}',
                    'medicamento': nomeMed,
                  });
                }
              } catch (e) {
                debugPrint('⚠️ Erro ao processar horário: $e');
                continue;
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao extrair horários do medicamento ${med.id}: $e');
          }
          
          // Verificar estoque baixo
          try {
            final quantidade = med.quantidade ?? 0;
            if (quantidade < 10 && quantidade >= 0) {
              final nomeMed = med.nome ?? 'Medicamento';
              alertas.add({
                'tipo': 'estoque',
                'mensagem': '$nomeMed - Estoque baixo',
                'horario': agora.toString().substring(11, 16),
                'medicamento': nomeMed,
              });
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao verificar estoque: $e');
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao processar medicamento: $e');
          continue;
        }
      }
      
      // Ordenar por horário (mais recente primeiro) e limitar a 3
      try {
        alertas.sort((a, b) {
          try {
            final horarioA = a['horario'] as String? ?? '';
            final horarioB = b['horario'] as String? ?? '';
            return horarioB.compareTo(horarioA);
          } catch (e) {
            return 0;
          }
        });
        return alertas.take(3).toList();
      } catch (e) {
        debugPrint('⚠️ Erro ao ordenar alertas: $e');
        return alertas.take(3).toList();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao gerar alertas: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  List<TimeOfDay> _extrairHorarios(Medicamento medicamento) {
    final frequencia = medicamento.frequencia;
    
    if (frequencia != null && frequencia.containsKey('horarios')) {
      final horariosList = frequencia['horarios'] as List?;
      if (horariosList != null) {
        return horariosList
            .map((h) => _parseTimeOfDay(h.toString()))
            .where((h) => h != null)
            .cast<TimeOfDay>()
            .toList();
      }
    }
    
    return [];
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      // Ignorar erro
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: const CareMindAppBar(
        isFamiliar: true,
        isIdoso: false,
      ),
      useSolidBackground: true,
      showWaves: false,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: DashboardSkeletonLoader(),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  try {
                    await _loadUserData();
                  } catch (e) {
                    debugPrint('❌ Erro ao atualizar dados: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Erro ao atualizar. Tente novamente.'),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                color: AppColors.primary,
                backgroundColor: Colors.white,
                strokeWidth: 2.5,
                displacement: 40,
                child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        AppSpacing.medium,
                        AppSpacing.large,
                        AppSpacing.large,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Olá, $_userName!',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Acompanhe o cuidado da sua família',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Banner de contexto (seletor já está na AppBar)
                  SliverToBoxAdapter(
                    child: ListenableBuilder(
                      listenable: getIt<FamiliarState>(),
                      builder: (context, _) {
                        final familiarState = getIt<FamiliarState>();
                        if (familiarState.idosoSelecionado != null) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.large,
                              vertical: AppSpacing.small,
                            ),
                            child: _buildSemaforoStatus(),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  // Card Status de Adesão
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                      child: _buildStatusAdesao(),
                    ),
                  ),
                  // Widget Alertas Recentes
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                      child: _buildAlertasRecentess(),
                    ),
                  ),
                  // Widget Última Atividade
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                      child: _buildUltimaAtividade(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.bottomNavBarPadding),
                  ),
                ],
              ),
      ),
        ),
    );
  }

  // Removido: _surfaceCard substituído por CareMindCard
  // Use: CareMindCard(variant: CardVariant.solid, ...)

  Widget _buildSemaforoStatus() {
    final familiarState = getIt<FamiliarState>();
    final idosoSelecionado = familiarState.idosoSelecionado;
    
    if (idosoSelecionado == null) return const SizedBox.shrink();

    final status = _statusIdosos[idosoSelecionado.id];
    final temAtraso = status?['temAtraso'] ?? false;
    final mensagem = status?['mensagem'] ?? 'Carregando status...';

    return CareMindCard(
      variant: CardVariant.solid,
      borderColor: (temAtraso ? AppColors.error : AppColors.success).withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (temAtraso ? AppColors.error : AppColors.success).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              temAtraso ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: temAtraso ? AppColors.error : AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  temAtraso ? 'Atenção necessária' : 'Tudo em dia!',
                  style: AppTextStyles.titleMedium,
                ),
                SizedBox(height: AppSpacing.xsmall),
                Text(
                  mensagem,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAdesao() {
    return ListenableBuilder(
      listenable: getIt<FamiliarState>(),
      builder: (context, _) {
        final familiarState = getIt<FamiliarState>();
        final idosoSelecionado = familiarState.idosoSelecionado;
        
        if (idosoSelecionado == null) {
          return const SizedBox.shrink();
        }

        final status = _statusIdosos[idosoSelecionado.id];
        final total = status?['total'] as int? ?? 0;
        final tomados = status?['tomados'] as int? ?? 0;
        final percentual = total > 0 ? (tomados / total * 100).round() : 0;

        return Column(
          children: [
            CareMindCard(
              variant: CardVariant.solid,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppSpacing.small + 4),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.14),
                          borderRadius: AppBorderRadius.smallAll,
                        ),
                        child: Icon(
                          Icons.analytics_outlined,
                          color: AppColors.info,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status de Adesão',
                              style: AppTextStyles.headlineSmall,
                            ),
                            SizedBox(height: AppSpacing.xsmall),
                            Text(
                              idosoSelecionado.nome ?? 'Idoso',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.medium + 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: total > 0 ? tomados / total : 0,
                              strokeWidth: 8,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percentual >= 80 ? AppColors.success : percentual >= 50 ? AppColors.warning : AppColors.error,
                              ),
                            ),
                            Text(
                              '$percentual%',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$tomados de $total medicamentos',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'tomados hoje',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.medium),
            CareMindCard(
              variant: CardVariant.solid,
              padding: AppSpacing.paddingCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adesão Últimos 7 Dias',
                    style: AppTextStyles.titleMedium,
                  ),
                  SizedBox(height: AppSpacing.medium),
                  AdherenceBarChart(
                    data: _dadosAdesao,
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.medium),
            CareMindCard(
              variant: CardVariant.solid,
              padding: AppSpacing.paddingCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tendência Semanal',
                    style: AppTextStyles.titleMedium,
                  ),
                  SizedBox(height: AppSpacing.medium),
                  AdherenceLineChart(
                    data: _dadosAdesao,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlertasRecentess() {
    return ListenableBuilder(
      listenable: getIt<FamiliarState>(),
      builder: (context, _) {
        final familiarState = getIt<FamiliarState>();
        final idosoSelecionado = familiarState.idosoSelecionado;
        
        if (idosoSelecionado == null) {
          return const SizedBox.shrink();
        }

        if (_alertas.isEmpty) {
          return CareMindCard(
            variant: CardVariant.solid,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.small + 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.14),
                    borderRadius: AppBorderRadius.smallAll,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 28,
                  ),
                ),
                SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nenhum alerta recente',
                        style: AppTextStyles.headlineSmall,
                      ),
                      SizedBox(height: AppSpacing.xsmall),
                      Text(
                        'Tudo está em ordem!',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return CareMindCard(
          variant: CardVariant.solid,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.small + 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.14),
                      borderRadius: AppBorderRadius.smallAll,
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: AppSpacing.medium),
                  Text(
                    'Alertas Recentes',
                    style: AppTextStyles.headlineSmall,
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.medium),
              ..._alertas.map((alerta) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: alerta['tipo'] == 'atraso' ? AppColors.error : AppColors.warning,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alerta['horario'] as String,
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alerta['mensagem'] as String,
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUltimaAtividade() {
    return ListenableBuilder(
      listenable: getIt<FamiliarState>(),
      builder: (context, _) {
        final familiarState = getIt<FamiliarState>();
        final idosoSelecionado = familiarState.idosoSelecionado;
        
        if (idosoSelecionado == null || _ultimaAtividade == null) {
          return const SizedBox.shrink();
        }

        final agora = DateTime.now();
        final diferenca = agora.difference(_ultimaAtividade!);
        String textoAtividade;
        
        if (diferenca.inDays > 0) {
          textoAtividade = 'Visto há ${diferenca.inDays} dia(s)';
        } else if (diferenca.inHours > 0) {
          textoAtividade = 'Visto há ${diferenca.inHours} hora(s)';
        } else if (diferenca.inMinutes > 0) {
          textoAtividade = 'Visto há ${diferenca.inMinutes} minuto(s)';
        } else {
          textoAtividade = 'Visto agora';
        }

        return CareMindCard(
          variant: CardVariant.solid,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.small + 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: AppBorderRadius.smallAll,
                ),
                child: Icon(
                  Icons.access_time,
                  color: AppColors.accent,
                  size: 28,
                ),
              ),
              SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Última Atividade',
                      style: AppTextStyles.headlineSmall,
                    ),
                    SizedBox(height: AppSpacing.xsmall),
                    Text(
                      textoAtividade,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

