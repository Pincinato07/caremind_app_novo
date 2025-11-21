import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../core/injection/injection.dart';
import '../../core/state/familiar_state.dart';
import '../../models/medicamento.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/caremind_app_bar.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    // Escutar mudanças no FamiliarState
    final familiarState = getIt<FamiliarState>();
    familiarState.addListener(_onFamiliarStateChanged);
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
      final familiarState = getIt<FamiliarState>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        final perfil = await supabaseService.getProfile(user.id);
        if (perfil != null && mounted) {
          // Carregar idosos no FamiliarState (já deve estar carregado pelo shell, mas garantir)
          if (!familiarState.hasIdosos) {
            await familiarState.carregarIdosos(user.id);
          }
          
          // Carregar status do idoso selecionado
          if (familiarState.idosoSelecionado != null) {
            await _carregarStatusIdoso(familiarState.idosoSelecionado!.id);
          }

          setState(() {
            _userName = perfil.nome ?? 'Familiar';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _carregarStatusIdoso(String idosoId) async {
    try {
      final familiarState = getIt<FamiliarState>();
      final supabaseService = getIt<SupabaseService>();
      final medicamentoService = getIt<MedicamentoService>();
      
      // Carregar medicamentos
      final medicamentos = await medicamentoService.getMedicamentos(idosoId);
      
      // Carregar última atividade (updated_at do perfil)
      final perfilIdoso = await supabaseService.getProfile(idosoId);
      if (perfilIdoso != null) {
        _ultimaAtividade = perfilIdoso.createdAt; // Usar createdAt como fallback
      }
      
      // Gerar alertas baseados em medicamentos atrasados
      _alertas = _gerarAlertas(medicamentos);
      
      final pendentes = medicamentos.where((m) => !m.concluido).toList();
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
            'tomados': medicamentos.where((m) => m.concluido).length,
          };
        });
      }
    } catch (e) {
      // Erro ao carregar status
    }
  }

  List<Map<String, dynamic>> _gerarAlertas(List<Medicamento> medicamentos) {
    final alertas = <Map<String, dynamic>>[];
    final agora = DateTime.now();
    
    for (var med in medicamentos) {
      if (med.concluido) continue;
      
      // Verificar se há horários passados hoje
      final horarios = _extrairHorarios(med);
      for (var horario in horarios) {
        final horarioDateTime = DateTime(
          agora.year,
          agora.month,
          agora.day,
          horario.hour,
          horario.minute,
        );
        
        if (horarioDateTime.isBefore(agora)) {
          alertas.add({
            'tipo': 'atraso',
            'mensagem': '${med.nome} Atrasado',
            'horario': '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}',
            'medicamento': med.nome,
          });
        }
      }
      
      // Verificar estoque baixo
      if (med.quantidade < 10) {
        alertas.add({
          'tipo': 'estoque',
          'mensagem': '${med.nome} - Estoque baixo',
          'horario': agora.toString().substring(11, 16),
          'medicamento': med.nome,
        });
      }
    }
    
    // Ordenar por horário (mais recente primeiro) e limitar a 3
    alertas.sort((a, b) => (b['horario'] as String).compareTo(a['horario'] as String));
    return alertas.take(3).toList();
  }

  List<TimeOfDay> _extrairHorarios(Medicamento medicamento) {
    final frequencia = medicamento.frequencia;
    
    if (frequencia.containsKey('horarios')) {
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
      appBar: const CareMindAppBar(isFamiliar: true),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Olá, $_userName!',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Acompanhe o cuidado da sua família',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 18,
                              color: Colors.white.withValues(alpha: 0.95),
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
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                      child: _buildStatusAdesao(),
                    ),
                  ),
                  // Widget Alertas Recentes
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                      child: _buildAlertasRecentess(),
                    ),
                  ),
                  // Widget Última Atividade
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                      child: _buildUltimaAtividade(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 100), // Padding inferior para evitar corte pela navbar
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSemaforoStatus() {
    final familiarState = getIt<FamiliarState>();
    final idosoSelecionado = familiarState.idosoSelecionado;
    
    if (idosoSelecionado == null) return const SizedBox.shrink();

    final status = _statusIdosos[idosoSelecionado.id];
    final temAtraso = status?['temAtraso'] ?? false;
    final mensagem = status?['mensagem'] ?? 'Carregando status...';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderColor: temAtraso ? Colors.red.withValues(alpha: 0.6) : Colors.green.withValues(alpha: 0.6),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: temAtraso ? Colors.red : Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (temAtraso ? Colors.red : Colors.green).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              temAtraso ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: Colors.white,
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
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mensagem,
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
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

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status de Adesão',
                          style: GoogleFonts.leagueSpartan(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          idosoSelecionado.nome ?? 'Idoso',
                          style: GoogleFonts.leagueSpartan(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Gráfico circular
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: total > 0 ? tomados / total : 0,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentual >= 80 ? Colors.green : percentual >= 50 ? Colors.orange : Colors.red,
                          ),
                        ),
                        Text(
                          '$percentual%',
                          style: GoogleFonts.leagueSpartan(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
                          style: GoogleFonts.leagueSpartan(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'tomados hoje',
                          style: GoogleFonts.leagueSpartan(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
          return GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nenhum alerta recente',
                        style: GoogleFonts.leagueSpartan(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tudo está em ordem!',
                        style: GoogleFonts.leagueSpartan(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Alertas Recentes',
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._alertas.map((alerta) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: alerta['tipo'] == 'atraso' ? Colors.red : Colors.orange,
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
                              style: GoogleFonts.leagueSpartan(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alerta['mensagem'] as String,
                              style: GoogleFonts.leagueSpartan(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
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

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Última Atividade',
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      textoAtividade,
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
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
