import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/navigation/app_navigation.dart';
import '../../models/perfil.dart';
import '../../models/medicamento.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/app_button.dart';
import '../familia_gerenciamento/familiares_screen.dart';
import '../medication/add_edit_medicamento_form.dart';
import '../medication/gestao_medicamentos_screen.dart';
import '../compromissos/gestao_compromissos_screen.dart';
import '../compromissos/add_edit_compromisso_form.dart';
import '../rotinas/gestao_rotinas_screen.dart';
import '../shared/configuracoes_screen.dart';
import '../integracoes/integracoes_screen.dart';

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
  List<Perfil> _idosos = [];
  Perfil? _idosoSelecionado;
  Map<String, dynamic> _statusIdosos = {};

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
          final idosos = await supabaseService.getIdososVinculados(user.id);
          
          Perfil? selecionado;
          if (idosos.isNotEmpty) {
            selecionado = idosos.first;
            await _carregarStatusIdoso(selecionado.id);
          }

          setState(() {
            _userName = perfil.nome ?? 'Familiar';
            _idosos = idosos;
            _idosoSelecionado = selecionado;
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
      final medicamentoService = getIt<MedicamentoService>();
      final medicamentos = await medicamentoService.getMedicamentos(idosoId);
      
      final pendentes = medicamentos.where((m) => !m.concluido).toList();
      final temAtraso = pendentes.isNotEmpty;
      final mensagemStatus = pendentes.isEmpty
          ? '${_idosoSelecionado?.nome ?? "Idoso"} tomou tudo hoje.'
          : '${_idosoSelecionado?.nome ?? "Idoso"} tem ${pendentes.length} medicamento(s) pendente(s).';

      setState(() {
        _statusIdosos[idosoId] = {
          'temAtraso': temAtraso,
          'mensagem': mensagemStatus,
          'totalPendentes': pendentes.length,
        };
      });
    } catch (e) {
      // Erro ao carregar status
    }
  }

  Future<void> _onIdosoSelecionado(Perfil idoso) async {
    setState(() {
      _idosoSelecionado = idoso;
    });
    await _carregarStatusIdoso(idoso.id);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
                            'Acompanhe o cuidado da sua família',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_idosos.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildIdosoSelector(),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (_idosoSelecionado != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildSemaforoStatus(),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildActionGrid(),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }

  Widget _buildIdosoSelector() {
    if (_idosos.length == 1) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acompanhando:',
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _idosoSelecionado?.nome ?? 'Idoso',
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Perfil>(
          value: _idosoSelecionado,
          isExpanded: true,
          dropdownColor: const Color(0xFF9B7EFF),
          icon: Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.9)),
          style: GoogleFonts.leagueSpartan(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          items: _idosos.map((idoso) {
            return DropdownMenuItem<Perfil>(
              value: idoso,
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.white.withValues(alpha: 0.9), size: 20),
                  const SizedBox(width: 12),
                  Text(idoso.nome ?? 'Idoso'),
                ],
              ),
            );
          }).toList(),
          onChanged: (Perfil? novoIdoso) {
            if (novoIdoso != null) {
              _onIdosoSelecionado(novoIdoso);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSemaforoStatus() {
    if (_idosoSelecionado == null) return const SizedBox.shrink();

    final status = _statusIdosos[_idosoSelecionado!.id];
    final temAtraso = status?['temAtraso'] ?? false;
    final mensagem = status?['mensagem'] ?? 'Carregando status...';

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: temAtraso ? Colors.red.withValues(alpha: 0.5) : Colors.green.withValues(alpha: 0.5),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: temAtraso ? Colors.red : Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (temAtraso ? Colors.red : Colors.green).withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              mensagem,
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

  Widget _buildActionGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildActionCard(
          icon: Icons.add_circle_outline,
          title: 'Adicionar Remédio',
          subtitle: _idosoSelecionado != null
              ? 'Para ${_idosoSelecionado!.nome}'
              : 'Selecione um idoso',
          color: const Color(0xFFE91E63),
          onTap: _idosoSelecionado != null
              ? () {
                  AppNavigation.pushWithHaptic(
                    context,
                    AddEditMedicamentoForm(idosoId: _idosoSelecionado!.id),
                  );
                }
              : null,
        ),
        if (_idosoSelecionado != null) ...[
          const SizedBox(height: 16),
          _buildActionCard(
            icon: Icons.add_circle_outline,
            title: 'Adicionar Compromisso',
            subtitle: 'Para ${_idosoSelecionado!.nome}',
            color: const Color(0xFF2196F3),
            onTap: () {
              AppNavigation.pushWithHaptic(
                context,
                AddEditCompromissoForm(idosoId: _idosoSelecionado!.id),
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.calendar_today,
          title: 'Agenda Médica',
          subtitle: _idosoSelecionado != null
              ? 'Compromissos de ${_idosoSelecionado!.nome}'
              : 'Compromissos e consultas',
          color: const Color(0xFF2196F3),
          onTap: _idosoSelecionado != null
              ? () {
                  AppNavigation.pushWithHaptic(
                    context,
                    GestaoCompromissosScreen(idosoId: _idosoSelecionado!.id),
                  );
                }
              : () {
                  AppNavigation.pushWithHaptic(
                    context,
                    const GestaoCompromissosScreen(),
                  );
                },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.medication_liquid,
          title: 'Meus Medicamentos',
          subtitle: 'Gerenciar meus medicamentos',
          color: const Color(0xFFE91E63),
          onTap: () {
            AppNavigation.pushWithHaptic(
              context,
              const GestaoMedicamentosScreen(),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.schedule_rounded,
          title: 'Minhas Rotinas',
          subtitle: 'Gerenciar minhas rotinas',
          color: const Color(0xFF4CAF50),
          onTap: () {
            AppNavigation.pushWithHaptic(
              context,
              const GestaoRotinasScreen(),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.camera_alt,
          title: 'Integrações (OCR)',
          subtitle: 'Leitura de receita com IA',
          color: const Color(0xFF9C27B0),
          onTap: () {
            AppNavigation.pushWithHaptic(
              context,
              const IntegracoesScreen(),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.settings,
          title: 'Configurações',
          subtitle: 'Configurações do app',
          color: const Color(0xFF607D8B),
          onTap: () {
            AppNavigation.pushWithHaptic(
              context,
              const ConfiguracoesScreen(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
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
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 18,
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
