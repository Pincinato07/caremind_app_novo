import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../core/injection/injection.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/historico_eventos_service.dart';
import '../../services/accessibility_service.dart';
import '../../core/accessibility/voice_navigation_service.dart';
import '../../core/accessibility/tts_enhancer.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/voice_interface_widget.dart';
import '../../core/navigation/app_navigation.dart';
import '../../screens/shared/configuracoes_screen.dart';
import '../../screens/idoso/ajuda_screen.dart';
import '../../models/medicamento.dart';

/// Dashboard do IDOSO - Foco em Acessibilidade Extrema (WCAG AAA)
/// Objetivo: Autonomia. O idoso não "gerencia"; ele "executa" e "consulta".
class IdosoDashboardScreen extends StatefulWidget {
  const IdosoDashboardScreen({super.key});

  @override
  State<IdosoDashboardScreen> createState() => _IdosoDashboardScreenState();
}

class _IdosoDashboardScreenState extends State<IdosoDashboardScreen> with TickerProviderStateMixin {
  String _userName = 'Usuário';
  bool _isLoading = true;
  Medicamento? _proximoMedicamento;
  DateTime? _proximoHorarioAgendado; // Novo campo para armazenar o próximo horário agendado
  final VoiceNavigationService _voiceNavigation = VoiceNavigationService();

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _loadUserData();
    // Inicializa o serviço de acessibilidade
    AccessibilityService.initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Leitura automática do título da tela se habilitada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSEnhancer.announceScreenChange(
        context, 
        'Dashboard',
        userName: _userName,
      );
    });
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
          
          // Verificar status de hoje
          Map<int, bool> statusMedicamentos = {};
          if (medicamentos.isNotEmpty) {
            final ids = medicamentos.where((m) => m.id != null).map((m) => m.id!).toList();
            statusMedicamentos = await HistoricoEventosService.checkMedicamentosConcluidosHoje(user.id, ids);
          }
          
          // Encontrar o próximo medicamento e seu horário agendado
          Medicamento? proximo;
          DateTime? proximoHorario;
          
          final agora = DateTime.now();
          final hoje = DateTime(agora.year, agora.month, agora.day);

          for (var med in medicamentos) {
            // Ignorar se já foi tomado
            if (statusMedicamentos[med.id] ?? false) continue;

            final horariosTd = _extrairHorarios(med); // Extrai TimeOfDay
            
            for (var horarioTd in horariosTd) {
              final horarioAgendado = DateTime(
                hoje.year,
                hoje.month,
                hoje.day,
                horarioTd.hour,
                horarioTd.minute,
              );

              // Considerar apenas horários no futuro ou que acabaram de passar
              // Para garantir que o idoso sempre veja o "próximo" item, mesmo que um pouco atrasado.
              if (horarioAgendado.isAfter(agora.subtract(const Duration(minutes: 10)))) { // Tolerância de 10min de atraso para ainda ser "próximo"
                if (proximoHorario == null || horarioAgendado.isBefore(proximoHorario)) {
                  proximo = med;
                  proximoHorario = horarioAgendado;
                }
              }
            }
          }

          setState(() {
            _userName = perfil.nome ?? 'Usuário';
            _proximoMedicamento = proximo;
            _proximoHorarioAgendado = proximoHorario;
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

  /// Extrai horários da frequência do medicamento (como feito no FamiliarDashboard)
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
    
    // Se não tem horários explícitos, retornar lista vazia
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

  Future<void> _marcarComoTomado() async {
    if (_proximoMedicamento == null || _proximoHorarioAgendado == null) return;

    // Trava de segurança para evitar marcação muito antecipada
    final agora = DateTime.now();
    const earlyTakeThresholdMinutes = 120; // 2 horas de antecedência (conforme solicitação)

    if (agora.isBefore(_proximoHorarioAgendado!) && 
        _proximoHorarioAgendado!.difference(agora).inMinutes > earlyTakeThresholdMinutes) {
      
      final horaFormatada = '${_proximoHorarioAgendado!.hour.toString().padLeft(2, '0')}:${_proximoHorarioAgendado!.minute.toString().padLeft(2, '0')}';

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Atenção ao Horário'),
          content: Text(
            'O horário deste remédio é só às $horaFormatada. A senhora está tomando agora mesmo?',
            style: AppTextStyles.leagueSpartan(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Não', style: TextStyle(color: Colors.red, fontSize: 18)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sim, estou', style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        // Usuário cancelou a confirmação
        await AccessibilityService.feedbackNegativo();
        await TTSEnhancer.announceCriticalError('Confirmação cancelada.');
        return;
      }
    }

    try {
      final medicamentoService = getIt<MedicamentoService>();
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) return;
      
      // Marcar como concluído
      await medicamentoService.toggleConcluido(
        _proximoMedicamento!.id!,
        true,
        _proximoHorarioAgendado!, // Usar o horário agendado para registro no histórico
      );

      // Feedback multissensorial: vibração longa + som
      await AccessibilityService.feedbackSucesso();

      // Anuncia sucesso com TTS avançado
      await TTSEnhancer.announceCriticalSuccess('Medicamento marcado como tomado');

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
                : RefreshIndicator(
                    onRefresh: () async {
                      // Recarregar dados do dashboard
                      setState(() {
                        _isLoading = true;
                      });
                      // Simular recarregamento (ajustar conforme necessário)
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
                    color: Colors.white,
                    backgroundColor: AppColors.primary,
                    strokeWidth: 2.5,
                    displacement: 40,
                    child: CustomScrollView(
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
                                  style: AppTextStyles.leagueSpartan(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Olá, $_userName',
                                  style: AppTextStyles.leagueSpartan(
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
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
                      child: _buildHeroCard(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Botão SOS Destacado
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
                      child: _buildSOSButton(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Grid de Ação
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
                      child: _buildActionGrid(),
                    ),
                  ),

                      SliverToBoxAdapter(child: SizedBox(height: AppSpacing.bottomNavBarPadding)),
                    ],
                  ),
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
      return AnimatedCard(
        index: 0,
        child: CareMindCard(
          variant: CardVariant.glass,
          padding: AppSpacing.paddingXLarge,
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green.shade300,
              ),
              SizedBox(height: AppSpacing.medium),
              Text(
                'Tudo em dia!',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: AppSpacing.small),
              Text(
                'Não há medicamentos pendentes no momento.',
                textAlign: TextAlign.center,
                style: AppTextStyles.leagueSpartan(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final horaPrevista = _proximoHorarioAgendado != null
        ? '${_proximoHorarioAgendado!.hour.toString().padLeft(2, '0')}:${_proximoHorarioAgendado!.minute.toString().padLeft(2, '0')}'
        : 'Horário desconhecido';

    return AnimatedCard(
      index: 1,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: AppSpacing.paddingXLarge,
        child: Column(
        children: [
          // Ícone de medicamento
          Container(
            padding: AppSpacing.paddingLarge,
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
          
          // Texto "Agora:" ou "Próximo às:"
          Text(
            _proximoHorarioAgendado != null && _proximoHorarioAgendado!.isBefore(DateTime.now().add(const Duration(minutes: 10)))
                ? 'Agora:'
                : 'Próximo às:',
            style: AppTextStyles.leagueSpartan(
              fontSize: 20,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          
          // Horário Previsto
          Text(
            horaPrevista,
            style: AppTextStyles.leagueSpartan(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Nome do medicamento (TEXTO GIGANTE)
          GestureDetector(
            onTap: () {
              // Text-to-Speech ao tocar no nome
              AccessibilityService.speak(
                '${_proximoMedicamento!.nome}, ${_proximoMedicamento!.dosagem ?? 'dosagem não especificada'}',
              );
            },
            child: Text(
              '${_proximoMedicamento!.nome}',
              textAlign: TextAlign.center,
              style: AppTextStyles.leagueSpartan(
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
            _proximoMedicamento!.dosagem ?? 'Dosagem não especificada',
            textAlign: TextAlign.center,
            style: AppTextStyles.leagueSpartan(
              fontSize: 24,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppSpacing.xlarge),
          
          // Botão GIGANTE "JÁ TOMEI"
          Semantics(
            label: 'Botão Já Tomei',
            hint: 'Toque para marcar o próximo medicamento como tomado',
            button: true,
            child: SizedBox(
              width: double.infinity,
              height: 80, // Botão gigante para acessibilidade
              child: ElevatedButton(
                onPressed: _marcarComoTomado,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.mediumAll,
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'JÁ TOMEI',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return Semantics(
      label: 'Botão SOS de Emergência',
      hint: 'Toque para abrir a tela de emergência e alertar todos os familiares',
      button: true,
      child: AnimatedCard(
        index: 2,
        child: CareMindCard(
          variant: CardVariant.glass,
          padding: AppSpacing.paddingLarge,
        onTap: () {
          AccessibilityService.vibrar(duration: 200);
          Navigator.push(
            context,
            AppNavigation.smoothRoute(
              const AjudaScreen(),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: AppSpacing.paddingCard,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 32,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚨 EMERGÊNCIA',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Alerta todos os familiares',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botão de Voz (Destaque) - Agora com interface completa
        Semantics(
          label: 'Assistente de voz CareMind',
          hint: 'Toque para ativar comandos de voz e controlar o app',
          button: true,
          child: _buildActionButton(
            icon: Icons.mic,
            label: 'Falar com CareMind',
            subtitle: 'Toque para ativar o assistente de voz',
            color: AppColors.primary,
            onTap: () {
              // A interface de voz flutuante já está disponível
              // Este botão serve como atalho visual
              AccessibilityService.speak(
                'Assistente de voz ativado. Toque no botão de microfone no canto da tela para começar.',
              );
            },
            isLarge: true,
          ),
        ),
        const SizedBox(height: 16),
        
        // Botão Meus Remédios
        Semantics(
          label: 'Meus Remédios',
          hint: 'Toque para ver e gerenciar seus medicamentos',
          button: true,
          child: _buildActionButton(
            icon: Icons.medication_liquid,
            label: 'Meus Remédios',
            color: const Color(0xFFE91E63),
            onTap: () async {
              await _voiceNavigation.navigateToScreen(context, VoiceScreen.medications);
              await TTSEnhancer.announceNavigation('Dashboard', 'Medicamentos');
            },
          ),
        ),
        const SizedBox(height: 16),
        
        // Botão Ajuda/Emergência (mantido para compatibilidade)
        Semantics(
          label: 'Ajuda e Emergência',
          hint: 'Toque para abrir a tela de emergência',
          button: true,
          child: _buildActionButton(
            icon: Icons.help_outline,
            label: 'Ajuda',
            color: Colors.blue,
            onTap: () async {
              Navigator.push(
                context,
                AppNavigation.smoothRoute(
                  const AjudaScreen(),
                ),
              );
              await TTSEnhancer.announceNavigation('Dashboard', 'Ajuda e Emergência');
            },
          ),
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
    return AnimatedCard(
      index: 4,
      child: CareMindCard(
        variant: CardVariant.glass,
        onTap: () {
          AccessibilityService.vibrar();
          onTap();
        },
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: isLarge ? AppSpacing.large : AppSpacing.medium + 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isLarge ? 36 : 28, color: Colors.white),
                SizedBox(width: AppSpacing.medium),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.leagueSpartan(
                      fontSize: isLarge ? 24 : 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              SizedBox(height: AppSpacing.xsmall),
              Text(
                subtitle,
                style: AppTextStyles.leagueSpartan(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
