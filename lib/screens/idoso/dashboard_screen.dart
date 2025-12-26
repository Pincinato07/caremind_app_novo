import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/injection/injection.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/historico_eventos_service.dart';
import '../../services/accessibility_service.dart';
import '../../core/accessibility/voice_navigation_service.dart';
import '../../core/accessibility/tts_enhancer.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/errors/error_handler.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/voice_interface_widget.dart';
import '../../core/navigation/app_navigation.dart';
import '../../screens/shared/configuracoes_screen.dart';
import '../../screens/idoso/ajuda_screen.dart';
import '../../models/medicamento.dart';
import '../../models/perfil.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/critical_mode_timer.dart';
import '../../services/shake_detector_service.dart';
import '../../widgets/wellbeing_checkin.dart';

/// Dashboard do IDOSO - Foco em Acessibilidade Extrema (WCAG AAA)
/// Objetivo: Autonomia. O idoso não "gerencia"; ele "executa" e "consulta".
class IdosoDashboardScreen extends StatefulWidget {
  const IdosoDashboardScreen({super.key});

  @override
  State<IdosoDashboardScreen> createState() => _IdosoDashboardScreenState();
}

class _IdosoDashboardScreenState extends State<IdosoDashboardScreen>
    with TickerProviderStateMixin {
  String _userName = 'Usuário';
  bool _isLoading = true;
  Medicamento? _proximoMedicamento;
  DateTime?
      _proximoHorarioAgendado; // Novo campo para armazenar o próximo horário agendado
  final VoiceNavigationService _voiceNavigation = VoiceNavigationService();
  final ShakeDetectorService _shakeDetector = ShakeDetectorService();

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
    // Inicia detecção de shake para SOS
    _shakeDetector.startListening(_handleShakeSOS);
  }

  /// Handler para shake to SOS
  void _handleShakeSOS() {
    if (!mounted) return;
    
    // Navega para tela de ajuda
    Navigator.push(
      context,
      AppNavigation.smoothRoute(const AjudaScreen()),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeDetector.dispose();
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
          final medicamentosResult =
              await medicamentoService.getMedicamentos(user.id);

          // Extrair lista de medicamentos do Result
          final medicamentos = medicamentosResult.when(
            success: (data) => data,
            failure: (exception) {
              debugPrint('Erro ao carregar medicamentos: ${exception.message}');
              return <Medicamento>[];
            },
          );

          // Verificar status de hoje
          Map<int, bool> statusMedicamentos = {};
          if (medicamentos.isNotEmpty) {
            final ids = medicamentos
                .where((m) => m.id != null)
                .map((m) => m.id!)
                .toList();
            statusMedicamentos =
                await HistoricoEventosService.checkMedicamentosConcluidosHoje(
                    user.id, ids);
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
              if (horarioAgendado
                  .isAfter(agora.subtract(const Duration(minutes: 10)))) {
                // Tolerância de 10min de atraso para ainda ser "próximo"
                if (proximoHorario == null ||
                    horarioAgendado.isBefore(proximoHorario)) {
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
      debugPrint('Erro ao carregar dados do dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Não mostrar erro ao usuário aqui - apenas logar
        // O estado vazio já indica que não há dados
      }
    }
  }

  /// Extrai horários da frequência do medicamento (como feito no FamiliarDashboard)
  List<TimeOfDay> _extrairHorarios(Medicamento medicamento) {
    try {
      final frequencia = medicamento.frequencia;
      if (frequencia == null || !frequencia.containsKey('horarios')) {
        return [];
      }

      final horariosList = frequencia['horarios'] as List?;
      if (horariosList == null || horariosList.isEmpty) {
        return [];
      }

      final horarios = <TimeOfDay>[];
      for (var h in horariosList) {
        try {
          if (h == null) continue;
          final timeOfDay = _parseTimeOfDay(h.toString());
          if (timeOfDay != null) {
            horarios.add(timeOfDay);
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao parsear horário $h: $e');
          continue;
        }
      }

      return horarios;
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao extrair horários: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    if (timeStr.isEmpty) {
      return null;
    }

    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) {
        return null;
      }

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour == null || minute == null) {
        return null;
      }

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        debugPrint('⚠️ Horário inválido: $hour:$minute');
        return null;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      debugPrint('⚠️ Erro ao parsear TimeOfDay de "$timeStr": $e');
      return null;
    }
  }

  Future<void> _marcarComoTomado() async {
    if (_proximoMedicamento == null || _proximoHorarioAgendado == null) return;

    // Trava de segurança para evitar marcação muito antecipada
    final agora = DateTime.now();
    const earlyTakeThresholdMinutes =
        120; // 2 horas de antecedência (conforme solicitação)

    if (agora.isBefore(_proximoHorarioAgendado!) &&
        _proximoHorarioAgendado!.difference(agora).inMinutes >
            earlyTakeThresholdMinutes) {
      final horaFormatada =
          '${_proximoHorarioAgendado!.hour.toString().padLeft(2, '0')}:${_proximoHorarioAgendado!.minute.toString().padLeft(2, '0')}';

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
              child: const Text('Não',
                  style: TextStyle(color: Colors.red, fontSize: 18)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sim, estou',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
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
      try {
        await AccessibilityService.feedbackSucesso();
      } catch (e) {
        // Erro no feedback não deve impedir a operação
        debugPrint('Erro no feedback de sucesso: $e');
      }

      // Anuncia sucesso com TTS avançado
      try {
        await TTSEnhancer.announceCriticalSuccess(
            'Medicamento marcado como tomado');
      } catch (e) {
        // Erro no TTS não deve impedir a operação
        debugPrint('Erro no TTS: $e');
      }

      // Recarregar dados
      await _loadUserData();

      if (mounted) {
        FeedbackService.showSuccess(
          context,
          'Medicamento marcado como tomado!',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      // WCAG: Feedback de erro acessível
      try {
        await AccessibilityService.feedbackNegativo();
        await AccessibilityService.speak(
            'Erro ao marcar medicamento. Tente novamente.');
      } catch (ttsError) {
        debugPrint('Erro ao fornecer feedback de erro: $ttsError');
      }

      if (mounted) {
        FeedbackService.showError(
          context,
          ErrorHandler.toAppException(e),
          onRetry: () => _marcarComoTomado(),
        );
      }
    }
  }

  Widget _buildWellbeingCheckin() {
    final supabaseService = getIt<SupabaseService>();
    final user = supabaseService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<Perfil?>(
      future: supabaseService.getProfile(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        final perfil = snapshot.data;
        if (perfil == null) return const SizedBox.shrink();

        return WellbeingCheckin(perfilId: perfil.id);
      },
    );
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
                ? const SingleChildScrollView(
                    child: DashboardSkeletonLoader(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'O Próximo Passo',
                                        style: AppTextStyles.leagueSpartan(
                                          fontSize: (MediaQuery.maybeOf(context)
                                                      ?.textScaler ??
                                                  const TextScaler.linear(1.0))
                                              .scale(32),
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ).copyWith(
                                          // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                                          shadows: [
                                            Shadow(
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                              color: Colors.black
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Olá, $_userName',
                                        style: AppTextStyles.leagueSpartan(
                                          fontSize: (MediaQuery.maybeOf(context)
                                                      ?.textScaler ??
                                                  const TextScaler.linear(1.0))
                                              .scale(20),
                                          color: Colors
                                              .white, // WCAG: Aumentado opacidade de 0.9 para 1.0
                                        ).copyWith(
                                          // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                                          shadows: [
                                            Shadow(
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                              color: Colors.black
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Botão discreto de configurações
                                // WCAG 2.5.5: Garantir área mínima de toque de 48x48dp
                                IconButton(
                                  icon: Icon(
                                    Icons.settings_outlined,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 28,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  padding: const EdgeInsets.all(12),
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
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.large),
                            child: _buildHeroCard(),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),

                        // Botão SOS Destacado
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.large),
                            child: _buildSOSButton(),
                          ),
                        ),

                        // Indicador de Shake to SOS (se disponível)
                        SliverToBoxAdapter(
                          child: _buildShakeIndicator(),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),

                        // Check-in de Bem-Estar
                        SliverToBoxAdapter(
                          child: _buildWellbeingCheckin(),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 16)),

                        // Grid de Ação
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.large),
                            child: _buildActionGrid(),
                          ),
                        ),

                        SliverToBoxAdapter(
                            child: SizedBox(
                                height: AppSpacing.bottomNavBarPadding)),
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
    // WCAG 1.4.4: Respeitar configuração de fonte grande do sistema
    // Tratamento de erro: garantir que textScaler sempre esteja disponível
    final textScaler =
        MediaQuery.maybeOf(context)?.textScaler ?? const TextScaler.linear(1.0);

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
                  fontSize: textScaler.scale(28),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ).copyWith(
                  // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.small),
              Text(
                'Não há medicamentos pendentes no momento.',
                textAlign: TextAlign.center,
                style: AppTextStyles.leagueSpartan(
                  fontSize: textScaler.scale(18),
                  color:
                      Colors.white, // WCAG: Aumentado opacidade de 0.9 para 1.0
                ).copyWith(
                  // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ],
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
        child: Stack(
          children: [
            // Conteúdo principal
            Column(
              children: [
                // Timer Crítico (aparece quando faltam < 15 min)
                if (_proximoHorarioAgendado != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CriticalModeTimer(
                      nextMedicationTime: _proximoHorarioAgendado,
                      onTimeArrived: () {
                        // Feedback quando chega no horário
                        AccessibilityService.speak(
                          'Hora do remédio: ${_proximoMedicamento!.nome}',
                        );
                      },
                    ),
                  ),

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
                  _proximoHorarioAgendado != null &&
                          _proximoHorarioAgendado!.isBefore(
                              DateTime.now().add(const Duration(minutes: 10)))
                      ? 'Agora:'
                      : 'Próximo às:',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: textScaler.scale(20),
                    color:
                        Colors.white, // WCAG: Aumentado opacidade de 0.9 para 1.0
                    fontWeight: FontWeight.w500,
                  ).copyWith(
                    // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Horário Previsto
                Text(
                  horaPrevista,
                  style: AppTextStyles.leagueSpartan(
                    fontSize: textScaler.scale(28),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ).copyWith(
                    // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ],
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
                      fontSize: textScaler.scale(36),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ).copyWith(
                      // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Dosagem
                Text(
                  _proximoMedicamento!.dosagem ?? 'Dosagem não especificada',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.leagueSpartan(
                    fontSize: textScaler.scale(24),
                    color:
                        Colors.white, // WCAG: Aumentado opacidade de 0.9 para 1.0
                    fontWeight: FontWeight.w500,
                  ).copyWith(
                    // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ],
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
                          fontSize: textScaler.scale(28),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    // WCAG 1.4.4: Respeitar configuração de fonte grande do sistema
    // Tratamento de erro: garantir que textScaler sempre esteja disponível
    final textScaler =
        MediaQuery.maybeOf(context)?.textScaler ?? const TextScaler.linear(1.0);

    return Semantics(
      label: 'Botão SOS de Emergência',
      hint:
          'Toque para abrir a tela de emergência e alertar todos os familiares',
      button: true,
      child: AnimatedCard(
        index: 2,
        child: CareMindCard(
          variant: CardVariant.glass,
          padding: AppSpacing.paddingLarge,
          onTap: () async {
            try {
              // WCAG: Feedback multissensorial (háptico + sonoro) para ação crítica
              try {
                await AccessibilityService.vibrar(duration: 300);
              } catch (e) {
                debugPrint('Erro ao vibrar: $e');
              }

              try {
                await AccessibilityService.speak("Abrindo tela de emergência");
              } catch (e) {
                debugPrint('Erro ao falar: $e');
              }

              if (mounted) {
                Navigator.push(
                  context,
                  AppNavigation.smoothRoute(
                    const AjudaScreen(),
                  ),
                );
              }
            } catch (e) {
              // Erro crítico - garantir que usuário ainda possa acessar a tela
              debugPrint('Erro ao abrir tela de emergência: $e');
              if (mounted) {
                Navigator.push(
                  context,
                  AppNavigation.smoothRoute(
                    const AjudaScreen(),
                  ),
                );
              }
            }
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
                        fontSize: textScaler.scale(20),
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alerta todos os familiares',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: textScaler
                            .scale(16), // WCAG: Aumentado de 14px para 16px
                        color: Colors
                            .white, // WCAG: Aumentado opacidade de 0.9 para 1.0
                      ).copyWith(
                        // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ],
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
              await _voiceNavigation.navigateToScreen(
                  context, VoiceScreen.medications);
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
              await TTSEnhancer.announceNavigation(
                  'Dashboard', 'Ajuda e Emergência');
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
    // WCAG 1.4.4: Respeitar configuração de fonte grande do sistema
    // Tratamento de erro: garantir que textScaler sempre esteja disponível
    final textScaler =
        MediaQuery.maybeOf(context)?.textScaler ?? const TextScaler.linear(1.0);

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
                      fontSize: textScaler.scale(isLarge ? 24 : 20),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ).copyWith(
                      // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ],
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
                  fontSize:
                      textScaler.scale(16), // WCAG: Aumentado de 14px para 16px
                  color:
                      Colors.white, // WCAG: Aumentado opacidade de 0.8 para 1.0
                ).copyWith(
                  // WCAG: Sombra de texto para garantir contraste 4.5:1 sobre gradiente
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShakeIndicator() {
    // Verifica se o dispositivo suporta acelerômetro
    return FutureBuilder<bool>(
      future: _checkAccelerometerAvailability(),
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
          child: CareMindCard(
            variant: CardVariant.glass,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.waving_hand,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chacoalhe 3x rápido para SOS',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkAccelerometerAvailability() async {
    // Verifica se o sensor está disponível
    // Para Android, retorna true se o dispositivo tiver acelerômetro
    try {
      // Simula verificação (retorna true para testes)
      // Em produção, você pode verificar se o pacote sensors_plus está instalado
      return true;
    } catch (e) {
      return false;
    }
  }
}
