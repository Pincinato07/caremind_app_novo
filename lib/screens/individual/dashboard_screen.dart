import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/navigation/app_navigation.dart';
import '../../models/medicamento.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/app_button.dart';
import '../medication/gestao_medicamentos_screen.dart';
import '../medication/add_edit_medicamento_form.dart';
import '../compromissos/gestao_compromissos_screen.dart';
import '../compromissos/add_edit_compromisso_form.dart';
import 'rotina_screen.dart';

class IndividualDashboardScreen extends StatefulWidget {
  const IndividualDashboardScreen({super.key});

  @override
  State<IndividualDashboardScreen> createState() => _IndividualDashboardScreenState();
}

class _IndividualDashboardScreenState extends State<IndividualDashboardScreen> {
  String _userName = 'Usuário';
  bool _isLoading = true;
  
  int _totalMedicamentos = 0;
  int _totalRotinas = 0;
  int _totalCompromissos = 0;
  int _totalMetricas = 0;
  
  bool _temAtraso = false;
  String _mensagemStatus = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      if (user != null) {
        final perfil = await supabaseService.getProfile(user.id);
        if (perfil != null && mounted) {
          await _loadDashboardData(user.id, supabaseService);
          
          setState(() {
            _userName = perfil.nome ?? 'Usuário';
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

  Future<void> _loadDashboardData(String userId, SupabaseService supabaseService) async {
    try {
      final medicamentoService = getIt<MedicamentoService>();
      final medicamentos = await medicamentoService.getMedicamentos(userId);
      _totalMedicamentos = medicamentos.length;
      
      final pendentes = medicamentos.where((m) => !m.concluido).toList();
      if (pendentes.isEmpty) {
        _temAtraso = false;
        _mensagemStatus = 'Você tomou tudo hoje.';
      } else {
        _temAtraso = true;
        _mensagemStatus = 'Você tem ${pendentes.length} medicamento(s) pendente(s).';
      }

      final rotinasResponse = await supabaseService.client
          .from('rotinas')
          .select('id')
          .eq('perfil_id', userId);
      _totalRotinas = rotinasResponse.length;

      final hoje = DateTime.now();
      final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);
      final fimDia = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
      
      final compromissosResponse = await supabaseService.client
          .from('compromissos')
          .select('id')
          .eq('perfil_id', userId)
          .gte('data_hora', inicioDia.toIso8601String())
          .lte('data_hora', fimDia.toIso8601String());
      _totalCompromissos = compromissosResponse.length;

      final metricasResponse = await supabaseService.client
          .from('metricas_saude')
          .select('id')
          .eq('perfil_id', userId)
          .gte('data_hora', inicioDia.toIso8601String())
          .lte('data_hora', fimDia.toIso8601String());
      _totalMetricas = metricasResponse.length;
    } catch (e) {
      // Erro silencioso
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Bom dia! Como está se sentindo hoje?';
    } else if (hour < 18) {
      return 'Boa tarde! Vamos cuidar da sua saúde?';
    } else {
      return 'Boa noite! Que tal revisar o dia?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Olá, $_userName!',
                                      style: GoogleFonts.leagueSpartan(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _getGreeting(),
                                      style: GoogleFonts.leagueSpartan(
                                        fontSize: 16,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0400BA), Color(0xFF0600E0)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0400BA).withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: _buildSemaforoStatus(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(
                            'Coisas Importantes',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildListDelegate([
                        _buildImportantCard(
                          title: 'Próximos Medicamentos',
                          subtitle: '$_totalMedicamentos medicamentos',
                          icon: Icons.medication_liquid,
                          color: const Color(0xFFE91E63),
                          onTap: () {
                            AppNavigation.pushWithHaptic(
                              context,
                              const GestaoMedicamentosScreen(),
                            );
                          },
                        ),
                        _buildImportantCard(
                          title: 'Minha Rotina',
                          subtitle: 'Atividades diárias',
                          icon: Icons.schedule_rounded,
                          color: const Color(0xFF4CAF50),
                          onTap: () {
                            AppNavigation.pushWithHaptic(
                              context,
                              const RotinaScreen(),
                            );
                          },
                        ),
                        _buildImportantCard(
                          title: 'Compromissos',
                          subtitle: '$_totalCompromissos hoje',
                          icon: Icons.calendar_today,
                          color: const Color(0xFF2196F3),
                          onTap: () {
                            AppNavigation.pushWithHaptic(
                              context,
                              const GestaoCompromissosScreen(),
                            );
                          },
                        ),
                        _buildImportantCard(
                          title: 'Métricas',
                          subtitle: '$_totalMetricas hoje',
                          icon: Icons.analytics_outlined,
                          color: const Color(0xFF9C27B0),
                          onTap: () {
                            // TODO: Navegar para métricas
                          },
                        ),
                      ]),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ações Rápidas',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            title: 'Adicionar Medicamento',
                            subtitle: 'Registre um novo medicamento',
                            icon: Icons.add_circle_outline,
                            color: const Color(0xFFE91E63),
                            onTap: () {
                              AppNavigation.pushWithHaptic(
                                context,
                                const AddEditMedicamentoForm(),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            title: 'Minha Rotina',
                            subtitle: 'Acompanhe suas atividades',
                            icon: Icons.schedule_outlined,
                            color: const Color(0xFF4CAF50),
                            onTap: () {
                              AppNavigation.pushWithHaptic(
                                context,
                                const RotinaScreen(),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            title: 'Adicionar Compromisso',
                            subtitle: 'Nova consulta ou compromisso',
                            icon: Icons.event_outlined,
                            color: const Color(0xFF2196F3),
                            onTap: () {
                              AppNavigation.pushWithHaptic(
                                context,
                                const AddEditCompromissoForm(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }

  Widget _buildSemaforoStatus() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: _temAtraso 
          ? Colors.red.withValues(alpha: 0.5) 
          : Colors.green.withValues(alpha: 0.5),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _temAtraso ? Colors.red : Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_temAtraso ? Colors.red : Colors.green).withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _mensagemStatus.isNotEmpty ? _mensagemStatus : 'Carregando status...',
              style: GoogleFonts.leagueSpartan(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.leagueSpartan(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.leagueSpartan(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.white.withValues(alpha: 0.6),
            size: 16,
          ),
        ],
      ),
    );
  }
}
