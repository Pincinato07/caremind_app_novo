import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/rotina_service.dart';
import '../../services/accessibility_service.dart';
import '../../services/offline_cache_service.dart';
import '../../core/injection/injection.dart';
import '../../models/medicamento.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/voice_interface_widget.dart';
import '../../services/historico_eventos_service.dart';
import '../../core/accessibility/tts_enhancer.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/error_widget_with_retry.dart';
import '../../widgets/feedback_snackbar.dart';
import '../../widgets/confirm_medication_button.dart';
import '../../widgets/offline_indicator.dart';

class IndividualDashboardScreen extends StatefulWidget {
  const IndividualDashboardScreen({super.key});

  @override
  State<IndividualDashboardScreen> createState() => _IndividualDashboardScreenState();
}

class _IndividualDashboardScreenState extends State<IndividualDashboardScreen> {
  String _userName = 'Usuário';
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOffline = false;
  DateTime? _lastSync;
  
  List<Map<String, dynamic>> _rotinas = [];
  
  int _totalMedicamentos = 0;
  int _medicamentosTomados = 0;
  
  bool _temAtraso = false;
  String _mensagemStatus = '';
  
  Medicamento? _proximoMedicamento;
  DateTime? _proximoHorario;
  
  List<Medicamento> _medicamentosPendentes = [];
  Map<int, bool> _statusMedicamentos = {};
  Map<int, bool> _loadingMedicamentos = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    AccessibilityService.initialize();
    _listenToConnectivity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSEnhancer.announceScreenChange(
        context, 
        'Dashboard',
        userName: _userName,
      );
    });
  }

  void _listenToConnectivity() {
    OfflineCacheService.connectivityStream.listen((isOnline) {
      if (mounted) {
        final wasOffline = _isOffline;
        setState(() => _isOffline = !isOnline);
        
        if (wasOffline && isOnline) {
          _syncPendingActions();
          _loadUserData();
          if (mounted) {
            FeedbackSnackbar.success(context, 'Conexão restaurada! Sincronizando...');
          }
        }
      }
    });
  }

  Future<void> _syncPendingActions() async {
    final pendingActions = await OfflineCacheService.getPendingActions();
    if (pendingActions.isEmpty) return;
    
    for (final action in pendingActions) {
      try {
        if (action['type'] == 'toggle_medicamento') {
          final medicamentoService = getIt<MedicamentoService>();
          await medicamentoService.toggleConcluido(
            action['medicamento_id'] as int,
            action['concluido'] as bool,
            DateTime.parse(action['data'] as String),
          );
        }
      } catch (e) {
        debugPrint('Erro ao sincronizar ação pendente: $e');
      }
    }
    
    await OfflineCacheService.clearPendingActions();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final isOnline = await OfflineCacheService.isOnline();
    setState(() => _isOffline = !isOnline);
    
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      if (user != null) {
        if (isOnline) {
          final perfil = await supabaseService.getProfile(user.id);
          if (perfil != null && mounted) {
            await _loadDashboardData(user.id, supabaseService);
            _lastSync = DateTime.now();
            
            setState(() {
              _userName = perfil.nome ?? 'Usuário';
              _isLoading = false;
            });
          }
        } else {
          await _loadFromCache(user.id);
        }
      }
    } catch (e) {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      if (user != null) {
        await _loadFromCache(user.id);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadFromCache(String userId) async {
    try {
      final cachedMedicamentos = await OfflineCacheService.getCachedMedicamentos(userId);
      final cachedRotinas = await OfflineCacheService.getCachedRotinas(userId);
      _lastSync = await OfflineCacheService.getCacheTimestamp(userId, 'medicamentos');
      
      if (cachedMedicamentos.isNotEmpty || cachedRotinas.isNotEmpty) {
        _totalMedicamentos = cachedMedicamentos.length;
        _medicamentosPendentes = cachedMedicamentos;
        _rotinas = cachedRotinas;
        _mensagemStatus = 'Dados offline. Conecte-se para atualizar.';
        
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
        
        if (mounted) {
          FeedbackSnackbar.warning(context, 'Usando dados salvos (modo offline)');
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sem conexão e sem dados salvos';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar dados offline';
      });
    }
  }

  Future<void> _loadDashboardData(String userId, SupabaseService supabaseService) async {
    try {
      final medicamentoService = getIt<MedicamentoService>();
      final rotinaService = getIt<RotinaService>();
      
      final medicamentos = await medicamentoService.getMedicamentos(userId);
      
      // Salvar no cache offline
      await OfflineCacheService.cacheMedicamentos(userId, medicamentos);
      
      Map<int, bool> statusMedicamentos = {};
      if (medicamentos.isNotEmpty) {
        final ids = medicamentos.where((m) => m.id != null).map((m) => m.id!).toList();
        statusMedicamentos = await HistoricoEventosService.checkMedicamentosConcluidosHoje(userId, ids);
      }
      
      _statusMedicamentos = statusMedicamentos;
      _totalMedicamentos = medicamentos.length;
      _medicamentosTomados = medicamentos.where((m) => statusMedicamentos[m.id] ?? false).length;
      
      _proximoMedicamento = _calcularProximoMedicamento(medicamentos, statusMedicamentos);
      _medicamentosPendentes = medicamentos.where((m) => !(statusMedicamentos[m.id] ?? false)).toList();
      
      final rotinas = await rotinaService.getRotinas(userId);
      _rotinas = rotinas;
      
      // Salvar rotinas no cache
      await OfflineCacheService.cacheRotinas(userId, rotinas);
      
      final pendentes = medicamentos.where((m) => !(statusMedicamentos[m.id] ?? false)).toList();
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
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _confirmarMedicamento(Medicamento medicamento) async {
    if (medicamento.id == null) return;
    
    setState(() {
      _loadingMedicamentos[medicamento.id!] = true;
    });
    
    final isCurrentlyTaken = _statusMedicamentos[medicamento.id] ?? false;
    
    // Atualizar UI imediatamente (optimistic update)
    setState(() {
      _statusMedicamentos[medicamento.id!] = !isCurrentlyTaken;
      _loadingMedicamentos[medicamento.id!] = false;
      
      if (!isCurrentlyTaken) {
        _medicamentosTomados++;
        _medicamentosPendentes.removeWhere((m) => m.id == medicamento.id);
      } else {
        _medicamentosTomados--;
        _medicamentosPendentes.add(medicamento);
      }
      
      _temAtraso = _medicamentosPendentes.isNotEmpty;
      _mensagemStatus = _temAtraso 
          ? 'Você tem ${_medicamentosPendentes.length} medicamento(s) pendente(s).'
          : 'Você tomou tudo hoje.';
    });
    
    try {
      if (_isOffline) {
        // Salvar ação para sincronizar depois
        await OfflineCacheService.addPendingAction({
          'type': 'toggle_medicamento',
          'medicamento_id': medicamento.id,
          'concluido': !isCurrentlyTaken,
          'data': DateTime.now().toIso8601String(),
        });
        
        if (mounted) {
          FeedbackSnackbar.info(context, 'Salvo offline. Será sincronizado quando conectar.');
        }
      } else {
        final medicamentoService = getIt<MedicamentoService>();
        await medicamentoService.toggleConcluido(
          medicamento.id!,
          !isCurrentlyTaken,
          DateTime.now(),
        );
        
        if (mounted) {
          if (!isCurrentlyTaken) {
            FeedbackSnackbar.success(
              context, 
              '${medicamento.nome} marcado como tomado!',
              onUndo: () => _confirmarMedicamento(medicamento),
            );
          } else {
            FeedbackSnackbar.info(context, '${medicamento.nome} desmarcado');
          }
        }
      }
    } catch (e) {
      // Reverter mudança se falhou
      setState(() {
        _statusMedicamentos[medicamento.id!] = isCurrentlyTaken;
        if (!isCurrentlyTaken) {
          _medicamentosTomados--;
          _medicamentosPendentes.add(medicamento);
        } else {
          _medicamentosTomados++;
          _medicamentosPendentes.removeWhere((m) => m.id == medicamento.id);
        }
        _temAtraso = _medicamentosPendentes.isNotEmpty;
        _mensagemStatus = _temAtraso 
            ? 'Você tem ${_medicamentosPendentes.length} medicamento(s) pendente(s).'
            : 'Você tomou tudo hoje.';
      });
      
      if (mounted) {
        FeedbackSnackbar.error(
          context, 
          'Erro ao atualizar medicamento',
          onRetry: () => _confirmarMedicamento(medicamento),
        );
      }
    }
  }

  /// Calcula o próximo medicamento baseado nos horários
  Medicamento? _calcularProximoMedicamento(
    List<Medicamento> medicamentos, 
    Map<int, bool> statusMedicamentos
  ) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    
    Medicamento? proximo;
    DateTime? proximoHorario;
    
    for (var med in medicamentos) {
      // Ignorar se já foi tomado hoje
      if (statusMedicamentos[med.id] ?? false) continue;
      
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

    return OfflineIndicator(
      child: AppScaffoldWithWaves(
        appBar: const CareMindAppBar(),
        useSolidBackground: true,
        showWaves: false,
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: AppSpacing.paddingLarge,
                    child: ErrorWidgetWithRetry(
                      message: _errorMessage!,
                      onRetry: _loadUserData,
                    ),
                  ),
                )
              else if (_isLoading)
                const SingleChildScrollView(
                  child: DashboardSkeletonLoader(),
                )
              else
                RefreshIndicator(
                  onRefresh: _loadUserData,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  displacement: 40,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  if (_isOffline) const OfflineBadge(),
                                  const SizedBox(width: 8),
                                  Semantics(
                                    label: 'Botão ouvir resumo',
                                    hint: 'Lê em voz alta o resumo do seu dia',
                                    button: true,
                                    child: IconButton(
                                      onPressed: _readDashboardSummary,
                                      icon: Icon(Icons.volume_up, color: AppColors.textSecondary),
                                      iconSize: 28,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _getGreeting(),
                                      style: AppTextStyles.leagueSpartan(
                                        fontSize: 16,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_lastSync != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: LastSyncInfo(lastSync: _lastSync),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: _buildSemaforoStatus()
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: _buildProximoMedicamento()
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 100.ms)
                              .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 100.ms, curve: Curves.easeOut),
                        ),
                      ),
                      if (_medicamentosPendentes.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: _buildMedicamentosPendentes()
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 200.ms)
                                .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 200.ms, curve: Curves.easeOut),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: _buildTimelineRotina()
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 300.ms)
                              .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 300.ms, curve: Curves.easeOut),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.bottomNavBarPadding),
                      ),
                    ],
                  ),
                ),
              if (userId.isNotEmpty && !_isLoading && _errorMessage == null)
                VoiceInterfaceWidget(
                  userId: userId,
                  showAsFloatingButton: true,
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
    return Semantics(
      label: 'Status dos medicamentos',
      hint: 'Mostra se você está em dia com seus medicamentos',
      child: CareMindCard(
        variant: CardVariant.solid,
        borderColor: _temAtraso ? AppColors.error.withValues(alpha: 0.5) : AppColors.success.withValues(alpha: 0.4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (_temAtraso ? AppColors.error : AppColors.success).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _temAtraso ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: _temAtraso ? AppColors.error : AppColors.success,
                size: 28,
              ),
            ),
            SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mensagemStatus,
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xsmall),
                  Text(
                    '$_medicamentosTomados de $_totalMedicamentos medicamentos tomados hoje',
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
      ),
    );
  }

  Widget _buildProximoMedicamento() {
    if (_proximoMedicamento == null) {
      return Semantics(
        label: 'Medicamentos em dia',
        hint: 'Todos os medicamentos do dia foram tomados',
        child: CareMindCard(
          variant: CardVariant.solid,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
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
                      'Tudo tomado por hoje! ✅',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xsmall),
                    Text(
                      'Parabéns! Você está em dia com seus medicamentos.',
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
            'Próximo medicamento: ${_proximoMedicamento!.nome}, dosagem: ${_proximoMedicamento!.dosagem ?? 'não especificada'}, horário: $horarioStr',
          );
        },
        child: CareMindCard(
          variant: CardVariant.solid,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication_liquid,
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
                          'Próximo Medicamento',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xsmall),
                        Text(
                          _proximoMedicamento!.nome,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
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
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          horarioStr,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.small + 4),
                  Expanded(
                    child: Text(
                      _proximoMedicamento!.dosagem ?? 'Dosagem não especificada',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 14,
                        color: AppColors.textSecondary,
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

  Widget _buildMedicamentosPendentes() {
    return CareMindCard(
      variant: CardVariant.solid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.small + 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Medicamentos Pendentes',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_medicamentosPendentes.take(3).map((med) {
            final isLoading = _loadingMedicamentos[med.id] ?? false;
            final isConfirmed = _statusMedicamentos[med.id] ?? false;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.nome,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (med.dosagem != null)
                          Text(
                            med.dosagem!,
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ConfirmMedicationButton(
                    isConfirmed: isConfirmed,
                    isLoading: isLoading,
                    onConfirm: () => _confirmarMedicamento(med),
                    onUndo: () => _confirmarMedicamento(med),
                    medicationName: med.nome,
                  ),
                ],
              ),
            );
          })).toList(),
        ],
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
      child: CareMindCard(
        variant: CardVariant.solid,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.small + 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppSpacing.small + 4),
                Text(
                  'Próximas Atividades',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: AppSpacing.small + 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nome,
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                horario,
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

