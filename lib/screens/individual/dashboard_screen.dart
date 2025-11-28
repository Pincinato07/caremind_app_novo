import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/rotina_service.dart';
import '../../services/accessibility_service.dart';
import '../../core/injection/injection.dart';
import '../../models/medicamento.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/voice_interface_widget.dart';
import '../../core/accessibility/tts_enhancer.dart';

class IndividualDashboardScreen extends StatefulWidget {
  const IndividualDashboardScreen({super.key});

  @override
  State<IndividualDashboardScreen> createState() => _IndividualDashboardScreenState();
}

class _IndividualDashboardScreenState extends State<IndividualDashboardScreen> {
  String _userName = 'Usuário';
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _rotinas = [];
  
  int _totalMedicamentos = 0;
  int _medicamentosTomados = 0;
  
  bool _temAtraso = false;
  String _mensagemStatus = '';
  
  Medicamento? _proximoMedicamento;
  DateTime? _proximoHorario;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Inicializa o serviço de acessibilidade
    AccessibilityService.initialize();
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
      final rotinaService = getIt<RotinaService>();
      
      // Carregar medicamentos
      final medicamentos = await medicamentoService.getMedicamentos(userId);
      _totalMedicamentos = medicamentos.length;
      _medicamentosTomados = medicamentos.where((m) => m.concluido).length;
      
      // Calcular próximo medicamento
      _proximoMedicamento = _calcularProximoMedicamento(medicamentos);
      
      // Carregar rotinas
      final rotinas = await rotinaService.getRotinas(userId);
      _rotinas = rotinas;
      
      final pendentes = medicamentos.where((m) => !m.concluido).toList();
      if (pendentes.isEmpty) {
        _temAtraso = false;
        _mensagemStatus = 'Você tomou tudo hoje.';
      } else {
        _temAtraso = true;
        _mensagemStatus = 'Você tem ${pendentes.length} medicamento(s) pendente(s).';
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Erro silencioso
    }
  }

  /// Calcula o próximo medicamento baseado nos horários
  Medicamento? _calcularProximoMedicamento(List<Medicamento> medicamentos) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    
    Medicamento? proximo;
    DateTime? proximoHorario;
    
    for (var med in medicamentos) {
      if (med.concluido) continue;
      
      final horarios = _extrairHorarios(med);
      for (var horario in horarios) {
        final horarioDateTime = DateTime(
          hoje.year,
          hoje.month,
          hoje.day,
          horario.hour,
          horario.minute,
        );
        
        // Se o horário já passou hoje, considerar para amanhã
        final horarioFinal = horarioDateTime.isBefore(agora)
            ? horarioDateTime.add(const Duration(days: 1))
            : horarioDateTime;
        
        if (proximoHorario == null || horarioFinal.isBefore(proximoHorario)) {
          proximo = med;
          proximoHorario = horarioFinal;
        }
      }
    }
    
    _proximoHorario = proximoHorario;
    return proximo;
  }

  /// Extrai horários da frequência do medicamento
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

  /// Lê o resumo do dashboard
  Future<void> _readDashboardSummary() async {
    final buffer = StringBuffer();
    buffer.write('Resumo do seu dia, $_userName. ');
    
    // Status dos medicamentos
    if (_totalMedicamentos > 0) {
      buffer.write('Você tem $_totalMedicamentos medicamentos hoje. ');
      buffer.write('Já tomou $_medicamentosTomados. ');
      
      if (_temAtraso) {
        buffer.write(_mensagemStatus);
      } else {
        buffer.write('Parabéns! Está em dia com seus medicamentos.');
      }
      
      // Próximo medicamento
      if (_proximoMedicamento != null && _proximoHorario != null) {
        final timeStr = '${_proximoHorario!.hour.toString().padLeft(2, '0')}:${_proximoHorario!.minute.toString().padLeft(2, '0')}';
        buffer.write(' Próximo: ${_proximoMedicamento!.nome} às $timeStr.');
      }
    } else {
      buffer.write('Nenhum medicamento programado para hoje.');
    }
    
    // Rotinas
    if (_rotinas.isNotEmpty) {
      buffer.write(' Você tem ${_rotinas.length} rotinas para hoje.');
    }
    
    await AccessibilityService.speak(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = getIt<SupabaseService>();
    final user = supabaseService.currentUser;
    final userId = user?.id ?? '';

    return AppScaffoldWithWaves(
      appBar: const CareMindAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : CustomScrollView(
                    slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Olá, $_userName!',
                                  style: AppTextStyles.leagueSpartan(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              Semantics(
                                label: 'Botão ouvir resumo',
                                hint: 'Lê em voz alta o resumo do seu dia',
                                button: true,
                                child: IconButton(
                                  onPressed: _readDashboardSummary,
                                  icon: Icon(Icons.volume_up, 
                                           color: Colors.white.withValues(alpha: 0.8)),
                                  iconSize: 28,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getGreeting(),
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 18,
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: _buildSemaforoStatus(),
                    ),
                  ),
                  // Widget Próximo Medicamento
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: _buildProximoMedicamento(),
                    ),
                  ),
                  // Widget Timeline de Rotina
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: _buildTimelineRotina(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 100), // Padding inferior para evitar corte pela navbar
                  ),
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

  Widget _buildSemaforoStatus() {
    return Semantics(
      label: 'Status dos medicamentos',
      hint: 'Mostra se você está em dia com seus medicamentos',
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderColor: _temAtraso 
            ? Colors.red.withValues(alpha: 0.6) 
            : Colors.green.withValues(alpha: 0.6),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _temAtraso ? Colors.red : Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_temAtraso ? Colors.red : Colors.green).withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _temAtraso ? Icons.warning_rounded : Icons.check_circle_rounded,
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
                    _mensagemStatus,
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_medicamentosTomados de $_totalMedicamentos medicamentos tomados hoje',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProximoMedicamento() {
    if (_proximoMedicamento == null) {
      return Semantics(
        label: 'Medicamentos em dia',
        hint: 'Todos os medicamentos do dia foram tomados',
        child: GlassCard(
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
                      'Tudo tomado por hoje! ✅',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Parabéns! Você está em dia com seus medicamentos.',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final horarioStr = _proximoHorario != null
        ? '${_proximoHorario!.hour.toString().padLeft(2, '0')}:${_proximoHorario!.minute.toString().padLeft(2, '0')}'
        : '';

    return Semantics(
      label: 'Próximo medicamento',
      hint: '${_proximoMedicamento!.nome}, às $horarioStr. Toque para ouvir detalhes.',
      child: GestureDetector(
        onTap: () {
          AccessibilityService.speak(
            'Próximo medicamento: ${_proximoMedicamento!.nome}, dosagem: ${_proximoMedicamento!.dosagem}, horário: $horarioStr',
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.medication_liquid,
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
                          'Próximo Medicamento',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _proximoMedicamento!.nome,
                          style: AppTextStyles.leagueSpartan(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          horarioStr,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _proximoMedicamento!.dosagem,
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineRotina() {
    // Filtrar rotinas não concluídas e pegar as próximas 2
    final rotinasPendentes = _rotinas
        .where((r) => (r['concluida'] as bool? ?? false) == false)
        .take(2)
        .toList();

    if (rotinasPendentes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Próximas atividades',
      hint: 'Lista das próximas rotinas e atividades',
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Próximas Atividades',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...rotinasPendentes.asMap().entries.map((entry) {
              final index = entry.key;
              final rotina = entry.value;
              final nome = rotina['nome'] as String? ?? 'Atividade';
              final horario = rotina['horario'] as String? ?? '';
              
              return Semantics(
                label: 'Atividade $nome',
                hint: 'Horário: $horario. Toque para ouvir detalhes.',
                child: GestureDetector(
                  onTap: () {
                    AccessibilityService.speak(
                      'Atividade: $nome, horário: $horario',
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.only(bottom: index < rotinasPendentes.length - 1 ? 12 : 0),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nome,
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                horario,
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

}

