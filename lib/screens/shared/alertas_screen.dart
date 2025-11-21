// lib/screens/shared/alertas_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../core/state/familiar_state.dart';
import '../../core/injection/injection.dart';
import '../../services/relatorios_service.dart';
import '../../services/supabase_service.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
        title: 'Notificações',
        isFamiliar: isFamiliar,
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
                labelStyle: GoogleFonts.leagueSpartan(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.leagueSpartan(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Notificações'),
                  Tab(text: 'Relatórios'),
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
  Future<List<Map<String, dynamic>>>? _alertasFuture;

  @override
  void initState() {
    super.initState();
    _alertasFuture = _loadAlertas();
  }

  Future<List<Map<String, dynamic>>> _loadAlertas() async {
    try {
      final familiarState = getIt<FamiliarState>();
      final supabaseService = getIt<SupabaseService>();
      final relatoriosService = getIt<RelatoriosService>();
      final user = supabaseService.currentUser;

      if (user == null) {
        return [];
      }

      // Buscar perfil do usuário para determinar se é familiar ou individual
      final perfilUsuario = await supabaseService.getProfile(user.id);
      if (perfilUsuario == null) {
        return [];
      }

      // Buscar alertas (o método já detecta se é familiar ou individual)
      final alertas = await relatoriosService.getAlertasRecentes(user.id);

      // Enriquecer alertas com nome do perfil
      final alertasEnriquecidos = <Map<String, dynamic>>[];
      final isFamiliar = familiarState.hasIdosos;
      
      for (var alerta in alertas) {
        final perfilId = alerta['perfil_id'] as String?;
        if (perfilId != null) {
          try {
            final perfil = await supabaseService.getProfile(perfilId);
            String nomeExibicao;
            
            // Se for familiar e o evento for de um idoso, mostrar nome do idoso
            // Se for individual ou o evento for do próprio usuário, mostrar "Você"
            if (isFamiliar && perfilId != user.id) {
              nomeExibicao = perfil?.nome ?? 'Idoso';
            } else {
              nomeExibicao = 'Você';
            }
            
            alertasEnriquecidos.add({
              ...alerta,
              'idoso_nome': nomeExibicao,
            });
          } catch (e) {
            // Se não conseguir buscar o perfil, usar fallback
            final nomeExibicao = (isFamiliar && perfilId != user.id) ? 'Idoso' : 'Você';
            alertasEnriquecidos.add({
              ...alerta,
              'idoso_nome': nomeExibicao,
            });
          }
        }
      }

      return alertasEnriquecidos;
    } catch (e) {
      debugPrint('Erro ao carregar alertas: $e');
      return [];
    }
  }

  Color _getColorForTipoEvento(String tipoEvento) {
    final tipoLower = tipoEvento.toLowerCase();
    if (tipoLower.contains('atrasado') || 
        tipoLower.contains('nao_tomado') || 
        tipoLower.contains('nao_concluida')) {
      return Colors.red;
    } else if (tipoLower.contains('estoque')) {
      return Colors.orange;
    } else if (tipoLower.contains('tomado') || 
               tipoLower.contains('concluido') || 
               tipoLower.contains('realizado')) {
      return Colors.green;
    }
    return Colors.blue;
  }

  IconData _getIconForTipoEvento(String tipoEvento) {
    final tipoLower = tipoEvento.toLowerCase();
    if (tipoLower.contains('medicamento')) {
      return Icons.medication_liquid;
    } else if (tipoLower.contains('rotina')) {
      return Icons.schedule_rounded;
    } else if (tipoLower.contains('compromisso')) {
      return Icons.calendar_today;
    } else if (tipoLower.contains('estoque')) {
      return Icons.inventory_2;
    }
    return Icons.notifications_rounded;
  }

  String _formatarDataHora(String? dataHoraStr) {
    if (dataHoraStr == null) return '';
    try {
      final dataHora = DateTime.parse(dataHoraStr);
      final agora = DateTime.now();
      final diferenca = agora.difference(dataHora);

      if (diferenca.inDays > 0) {
        return '${diferenca.inDays} dia(s) atrás';
      } else if (diferenca.inHours > 0) {
        return '${diferenca.inHours} hora(s) atrás';
      } else if (diferenca.inMinutes > 0) {
        return '${diferenca.inMinutes} minuto(s) atrás';
      } else {
        return 'Agora';
      }
    } catch (e) {
      return dataHoraStr;
    }
  }

  String _formatarDataHoraCompleta(String? dataHoraStr) {
    if (dataHoraStr == null) return '';
    try {
      final dataHora = DateTime.parse(dataHoraStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dataHora);
    } catch (e) {
      return dataHoraStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _alertasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        }

        if (snapshot.hasError) {
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
                  'Erro ao carregar alertas',
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final alertas = snapshot.data ?? [];

        if (alertas.isEmpty) {
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
                  'Nenhum alerta',
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Tudo está em ordem! Não há notificações importantes no momento.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.leagueSpartan(
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
          onRefresh: () async {
            setState(() {
              _alertasFuture = _loadAlertas();
            });
            await _alertasFuture;
          },
          backgroundColor: Colors.white,
          color: const Color(0xFF0400BA),
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: alertas.length,
            itemBuilder: (context, index) {
              final alerta = alertas[index];
              final tipoEvento = alerta['tipo_evento'] as String? ?? 'evento';
              final descricao = alerta['descricao'] as String? ?? '';
              final dataHora = alerta['data_hora'] as String?;
              final idosoNome = alerta['idoso_nome'] as String? ?? 'Idoso';

              final color = _getColorForTipoEvento(tipoEvento);
              final icon = _getIconForTipoEvento(tipoEvento);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderColor: color.withValues(alpha: 0.3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícone colorido
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
                      const SizedBox(width: 16),
                      // Conteúdo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título: Nome do Idoso - Tipo do Evento
                            Text(
                              '$idosoNome - ${_formatarTipoEvento(tipoEvento)}',
                              style: GoogleFonts.leagueSpartan(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Data/Hora
                            Text(
                              _formatarDataHoraCompleta(dataHora),
                              style: GoogleFonts.leagueSpartan(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Tempo relativo
                            Text(
                              _formatarDataHora(dataHora),
                              style: GoogleFonts.leagueSpartan(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            if (descricao.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                descricao,
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatarTipoEvento(String tipoEvento) {
    final tipoLower = tipoEvento.toLowerCase();
    
    if (tipoLower.contains('medicamento_atrasado')) {
      return 'Medicamento Atrasado';
    } else if (tipoLower.contains('medicamento_nao_tomado')) {
      return 'Medicamento Não Tomado';
    } else if (tipoLower.contains('medicamento_tomado')) {
      return 'Medicamento Tomado';
    } else if (tipoLower.contains('estoque_baixo')) {
      return 'Estoque Baixo';
    } else if (tipoLower.contains('rotina_nao_concluida')) {
      return 'Rotina Não Concluída';
    } else if (tipoLower.contains('compromisso_atrasado')) {
      return 'Compromisso Atrasado';
    } else if (tipoLower.contains('rotina')) {
      return 'Rotina';
    } else if (tipoLower.contains('compromisso')) {
      return 'Compromisso';
    }
    
    // Capitalizar primeira letra
    return tipoEvento.split('_').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
