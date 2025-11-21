import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/historico_eventos_service.dart';
import '../../services/accessibility_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/navigation/app_navigation.dart';
import '../../models/medicamento.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/voice_interface_widget.dart';
import '../medication/gestao_medicamentos_screen.dart';
import '../shared/configuracoes_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dashboard do IDOSO - Foco em Acessibilidade Extrema (WCAG AAA)
/// Objetivo: Autonomia. O idoso não "gerencia"; ele "executa" e "consulta".
class IdosoDashboardScreen extends StatefulWidget {
  const IdosoDashboardScreen({super.key});

  @override
  State<IdosoDashboardScreen> createState() => _IdosoDashboardScreenState();
}

class _IdosoDashboardScreenState extends State<IdosoDashboardScreen> {
  String _userName = 'Usuário';
  bool _isLoading = true;
  Medicamento? _proximoMedicamento;
  List<Medicamento> _medicamentos = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Inicializa o serviço de acessibilidade
    AccessibilityService.initialize();
  }

  Future<void> _loadUserData() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final medicamentoService = getIt<MedicamentoService>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        final perfil = await supabaseService.getProfile(user.id);
        if (perfil != null && mounted) {
          // Buscar medicamentos
          final medicamentos = await medicamentoService.getMedicamentos(user.id);
          
          // Encontrar o próximo medicamento (primeiro não concluído)
          Medicamento? proximo;
          for (var med in medicamentos) {
            if (!med.concluido) {
              proximo = med;
              break;
            }
          }

          setState(() {
            _userName = perfil.nome ?? 'Usuário';
            _medicamentos = medicamentos;
            _proximoMedicamento = proximo;
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

  Future<void> _marcarComoTomado() async {
    if (_proximoMedicamento == null) return;

    try {
      final medicamentoService = getIt<MedicamentoService>();
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) return;
      
      // Marcar como concluído
      await medicamentoService.toggleConcluido(
        _proximoMedicamento!.id!,
        true,
      );

      // Registrar evento no histórico
      try {
        await HistoricoEventosService.addEvento({
          'perfil_id': user.id,
          'tipo_evento': 'medicamento_tomado',
          'data_hora': DateTime.now().toIso8601String(),
          'descricao': 'Medicamento "${_proximoMedicamento!.nome}" marcado como tomado',
          'referencia_id': _proximoMedicamento!.id.toString(),
          'tipo_referencia': 'medicamento',
        });
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        debugPrint('⚠️ Erro ao registrar evento no histórico: $e');
      }

      // Feedback multissensorial: vibração longa + som
      await AccessibilityService.feedbackSucesso();

      // Recarregar dados
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicamento marcado como tomado!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao marcar medicamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _ligarParaFamiliar() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuário não autenticado'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final cuidador = await supabaseService.getCuidadorPrincipal(user.id);
      final telefone = cuidador?['telefone'] as String?;
      final nomeCuidador = cuidador?['nome'] as String?;

      if (telefone == null || telefone.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Número não disponível',
                style: GoogleFonts.leagueSpartan(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                'Nenhum número de emergência cadastrado. Peça para seu familiar configurar o telefone no aplicativo.',
                style: GoogleFonts.leagueSpartan(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: GoogleFonts.leagueSpartan(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0400BA),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Formatar telefone para URL (remover caracteres não numéricos)
      final telefoneLimpo = telefone.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri.parse('tel:$telefoneLimpo');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Dispositivo não suportado',
                style: GoogleFonts.leagueSpartan(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                'Este dispositivo não possui capacidade de fazer chamadas telefônicas.',
                style: GoogleFonts.leagueSpartan(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: GoogleFonts.leagueSpartan(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0400BA),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e is AppException
            ? e.message
            : 'Erro ao iniciar chamada: $e';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = getIt<SupabaseService>();
    final user = supabaseService.currentUser;
    final userId = user?.id ?? '';

    return AppScaffoldWithWaves(
      body: SafeArea(
        child: Stack(
          children: [
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                  // Header simplificado com botão de configurações
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'O Próximo Passo',
                                  style: GoogleFonts.leagueSpartan(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Olá, $_userName',
                                  style: GoogleFonts.leagueSpartan(
                                    fontSize: 20,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Botão discreto de configurações
                          IconButton(
                            icon: Icon(
                              Icons.settings_outlined,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 28,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                AppNavigation.smoothRoute(
                                  const ConfiguracoesScreen(),
                                ),
                              );
                            },
                            tooltip: 'Configurações',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card Principal (Hero) - Próximo Medicamento
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildHeroCard(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Grid de Ação
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildActionGrid(),
                    ),
                  ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
            // Interface de voz flutuante
            if (userId.isNotEmpty && !_isLoading)
              VoiceInterfaceWidget(
                userId: userId,
                showAsFloatingButton: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    if (_proximoMedicamento == null) {
      return GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Tudo em dia!',
              style: GoogleFonts.leagueSpartan(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Não há medicamentos pendentes no momento.',
              textAlign: TextAlign.center,
              style: GoogleFonts.leagueSpartan(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Ícone de medicamento
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_liquid,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Texto "Agora:"
          Text(
            'Agora:',
            style: GoogleFonts.leagueSpartan(
              fontSize: 20,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          
          // Nome do medicamento (TEXTO GIGANTE)
          GestureDetector(
            onTap: () {
              // Text-to-Speech ao tocar no nome
              AccessibilityService.speak(
                '${_proximoMedicamento!.nome}, ${_proximoMedicamento!.dosagem}',
              );
            },
            child: Text(
              '${_proximoMedicamento!.nome}',
              textAlign: TextAlign.center,
              style: GoogleFonts.leagueSpartan(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Dosagem
          Text(
            _proximoMedicamento!.dosagem,
            textAlign: TextAlign.center,
            style: GoogleFonts.leagueSpartan(
              fontSize: 24,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          
          // Botão GIGANTE "JÁ TOMEI"
          SizedBox(
            width: double.infinity,
            height: 80, // Botão gigante para acessibilidade
            child: ElevatedButton(
              onPressed: _marcarComoTomado,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0400BA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Text(
                'JÁ TOMEI',
                style: GoogleFonts.leagueSpartan(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
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
        // Botão de Voz (Destaque) - Agora com interface completa
        _buildActionButton(
          icon: Icons.mic,
          label: 'Falar com CareMind',
          subtitle: 'Toque para ativar o assistente de voz',
          color: const Color(0xFF0400B9),
          onTap: () {
            // A interface de voz flutuante já está disponível
            // Este botão serve como atalho visual
            AccessibilityService.speak(
              'Assistente de voz ativado. Toque no botão de microfone no canto da tela para começar.',
            );
          },
          isLarge: true,
        ),
        const SizedBox(height: 16),
        
        // Botão Meus Remédios
        _buildActionButton(
          icon: Icons.medication_liquid,
          label: 'Meus Remédios',
          color: const Color(0xFFE91E63),
          onTap: () {
            Navigator.push(
              context,
              AppNavigation.smoothRoute(
                const GestaoMedicamentosScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        
        // Botão Ajuda/Emergência
        _buildActionButton(
          icon: Icons.phone,
          label: 'Ajuda / Emergência',
          color: Colors.red,
          onTap: _ligarParaFamiliar,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    return GlassCard(
      onTap: () {
        AccessibilityService.vibrar();
        onTap();
      },
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isLarge ? 24 : 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isLarge ? 36 : 28, color: Colors.white),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.leagueSpartan(
                    fontSize: isLarge ? 24 : 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.leagueSpartan(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

}
