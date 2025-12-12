import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/medicamento.dart';
import '../../services/medicamento_service.dart';
import '../../services/supabase_service.dart';
import '../../services/accessibility_service.dart';
import '../../services/offline_cache_service.dart';
import '../../services/subscription_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/state/familiar_state.dart';
import '../../core/accessibility/tts_enhancer.dart';
import '../../services/historico_eventos_service.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/banner_contexto_familiar.dart';
import '../../widgets/voice_interface_widget.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/error_widget_with_retry.dart';
import '../../widgets/feedback_snackbar.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/premium/premium_guard.dart';
import '../../widgets/premium/premium_sales_modal.dart';
import '../integracoes/integracoes_screen.dart';
import 'add_edit_medicamento_form.dart';

class GestaoMedicamentosScreen extends StatefulWidget {
  final String? idosoId; // Para familiar gerenciar medicamentos do idoso
  final bool embedded; // Se true, não mostra AppScaffoldWithWaves nem SliverAppBar

  const GestaoMedicamentosScreen({
    super.key,
    this.idosoId,
    this.embedded = false,
  });

  @override
  State<GestaoMedicamentosScreen> createState() => _GestaoMedicamentosScreenState();
}

class _GestaoMedicamentosScreenState extends State<GestaoMedicamentosScreen> {
  List<Medicamento> _medicamentos = [];
  Map<int, bool> _statusMedicamentos = {};
  bool _isLoading = true;
  String? _error;
  String? _perfilTipo;
  bool _isOffline = false;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadMedicamentos();
    
    final familiarState = getIt<FamiliarState>();
    familiarState.addListener(_onFamiliarStateChanged);
    
    AccessibilityService.initialize();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    OfflineCacheService.connectivityStream.listen((isOnline) {
      if (mounted) {
        final wasOffline = _isOffline;
        setState(() => _isOffline = !isOnline);
        
        if (wasOffline && isOnline) {
          _loadMedicamentos();
          if (mounted) {
            FeedbackSnackbar.success(context, 'Conexão restaurada!');
          }
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Leitura automática do título da tela se habilitada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSEnhancer.announceScreenChange(context, 'Medicamentos');
    });
  }

  @override
  void dispose() {
    final familiarState = getIt<FamiliarState>();
    familiarState.removeListener(_onFamiliarStateChanged);
    super.dispose();
  }

  void _onFamiliarStateChanged() {
    // Recarregar medicamentos quando o idoso selecionado mudar
    if (mounted && widget.idosoId == null) {
      _loadMedicamentos();
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      if (user != null) {
        final perfil = await supabaseService.getProfile(user.id);
        if (perfil != null && mounted) {
          setState(() {
            _perfilTipo = perfil.tipo?.toLowerCase();
          });
        }
      }
    } catch (e) {
      // Ignora erro ao carregar perfil
    }
  }

  bool get _isIdoso => _perfilTipo == 'idoso';
  bool get _isFamiliar {
    final familiarState = getIt<FamiliarState>();
    return familiarState.hasIdosos && widget.idosoId == null;
  }

  bool _isConcluido(Medicamento medicamento) {
    return _statusMedicamentos[medicamento.id] ?? false;
  }

  Future<void> _loadMedicamentos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final isOnline = await OfflineCacheService.isOnline();
    setState(() => _isOffline = !isOnline);

    try {
      final supabaseService = getIt<SupabaseService>();
      final medicamentoService = getIt<MedicamentoService>();
      final familiarState = getIt<FamiliarState>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        final targetId = widget.idosoId ?? 
            (familiarState.hasIdosos && familiarState.idosoSelecionado != null 
                ? familiarState.idosoSelecionado!.id 
                : user.id);
        
        if (isOnline) {
          final medicamentos = await medicamentoService.getMedicamentos(targetId);
          
          // Salvar no cache offline
          await OfflineCacheService.cacheMedicamentos(targetId, medicamentos);
          _lastSync = DateTime.now();
          
          Map<int, bool> status = {};
          if (medicamentos.isNotEmpty) {
            final medIds = medicamentos.where((m) => m.id != null).map((m) => m.id!).toList();
            if (medIds.isNotEmpty) {
              status = await HistoricoEventosService.checkMedicamentosConcluidosHoje(targetId, medIds);
            }
          }

          setState(() {
            _medicamentos = medicamentos;
            _statusMedicamentos = status;
            _isLoading = false;
          });
        } else {
          await _loadFromCache(targetId);
        }
      } else {
        setState(() {
          _error = 'Usuário não encontrado';
          _isLoading = false;
        });
      }
    } catch (error) {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      if (user != null) {
        await _loadFromCache(user.id);
      } else {
        final errorMessage = error is AppException
            ? error.message
            : 'Erro ao carregar medicamentos: $error';
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFromCache(String userId) async {
    try {
      final cachedMedicamentos = await OfflineCacheService.getCachedMedicamentos(userId);
      _lastSync = await OfflineCacheService.getCacheTimestamp(userId, 'medicamentos');
      
      if (cachedMedicamentos.isNotEmpty) {
        setState(() {
          _medicamentos = cachedMedicamentos;
          _isLoading = false;
          _isOffline = true;
        });
        
        if (mounted) {
          FeedbackSnackbar.warning(context, 'Usando dados salvos (modo offline)');
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Sem conexão e sem dados salvos';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erro ao carregar dados offline';
      });
    }
  }

  Future<void> _toggleConcluido(Medicamento medicamento) async {
    try {
      final medicamentoService = getIt<MedicamentoService>();
      final supabaseService = getIt<SupabaseService>();
      
      // Determinar o perfil_id do idoso (não do familiar)
      final user = supabaseService.currentUser;
      if (user == null) return;
      
      // Se for familiar gerenciando idoso, usar o id do idoso; senão usar o user.id
      
      final bool estaConcluido = _isConcluido(medicamento);
      final bool novoEstado = !estaConcluido;

      // Atualizar UI otimistamente
      setState(() {
        _statusMedicamentos[medicamento.id!] = novoEstado;
      });

      // Atualizar o medicamento no backend
      await medicamentoService.toggleConcluido(
        medicamento.id!,
        novoEstado,
        DateTime.now(), // data prevista
      );
      
      // Não precisamos recarregar tudo, pois já atualizamos o estado local
      // Apenas se houver erro reverteríamos, mas o catch cuida disso (embora aqui não revertamos explicitamente na UI,
      // uma recarga futura corrigiria). Para UX perfeita, poderíamos reverter no catch.
    } catch (error) {
       // Reverter estado em caso de erro
      setState(() {
        _statusMedicamentos[medicamento.id!] = !_statusMedicamentos[medicamento.id!]!;
      });

      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao atualizar medicamento: $error';
      _showError(errorMessage);
    }
  }

  Future<void> _deleteMedicamento(Medicamento medicamento) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o medicamento "${medicamento.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final medicamentoService = getIt<MedicamentoService>();
        await medicamentoService.deleteMedicamento(medicamento.id!);
        _loadMedicamentos(); // Recarrega a lista
        _showSuccess('Medicamento excluído com sucesso');
      } catch (error) {
        final errorMessage = error is AppException
            ? error.message
            : 'Erro ao excluir medicamento: $error';
        _showError(errorMessage);
      }
    }
  }

  void _showError(String message) {
    FeedbackSnackbar.error(context, message, onRetry: _loadMedicamentos);
  }

  void _showSuccess(String message) {
    FeedbackSnackbar.success(context, message);
  }

  /// Mostra diálogo com opções: Formulário ou OCR
  Future<void> _showAddMedicamentoOptions() async {
    final subscriptionService = getIt<SubscriptionService>();
    await subscriptionService.getPermissions();
    
    final quantidadeAtual = _medicamentos.length;
    final podeAdicionar = await subscriptionService.canAddMedicine(quantidadeAtual);
    
    if (!podeAdicionar && mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => const PremiumSalesModal(),
      );
      return;
    }

    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA8B8FF), Color(0xFF9B7EFF)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Como deseja adicionar?',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                // Opção: Formulário
                GlassCard(
                  onTap: () => Navigator.pop(context, 'formulario'),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: AppBorderRadius.mediumAll,
                        ),
                        child: const Icon(
                          Icons.edit_note,
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
                              'Formulário',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Preencher manualmente',
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
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Opção: OCR
                PremiumGuard(
                  isEnabled: getIt<SubscriptionService>().canUseOCR,
                  mode: PremiumGuardMode.blockTouch,
                  child: GlassCard(
                    onTap: () async {
                      final subscriptionService = getIt<SubscriptionService>();
                      await subscriptionService.getPermissions();
                      if (subscriptionService.canUseOCR && mounted) {
                        Navigator.pop(context, 'ocr');
                      }
                    },
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: AppBorderRadius.mediumAll,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
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
                                'Por Foto',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ler receita com inteligência artificial',
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
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (option == null) return;

    if (option == 'formulario') {
      // Abrir formulário padrão
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEditMedicamentoForm(idosoId: widget.idosoId),
        ),
      );
      if (result == true) {
        _loadMedicamentos();
      }
    } else if (option == 'ocr') {
      // Mostrar opções de câmera ou galeria
      await _showOcrImageSource();
    }
  }

  /// Mostra opções para escolher câmera ou galeria para OCR
  Future<void> _showOcrImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA8B8FF), Color(0xFF9B7EFF)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Escolha a origem da imagem',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                // Opção: Câmera
                GlassCard(
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: AppBorderRadius.mediumAll,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
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
                              'Tirar Foto',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Abrir a câmera',
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
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Opção: Galeria
                GlassCard(
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: AppBorderRadius.mediumAll,
                        ),
                        child: const Icon(
                          Icons.photo_library,
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
                              'Escolher da Galeria',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Selecionar do dispositivo',
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
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source == null) return;

    // Capturar/selecionar imagem
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // Obter idosoId do FamiliarState se não foi fornecido via widget
        final familiarState = getIt<FamiliarState>();
        final idosoId = widget.idosoId ?? 
            (familiarState.hasIdosos ? familiarState.idosoSelecionado?.id : null);
        
        // Abrir tela de OCR com a imagem selecionada
        final result = await Navigator.push(
          context,
          AppNavigation.smoothRoute(
            IntegracoesScreen(
              initialImage: File(image.path),
              idosoId: idosoId,
              onMedicamentosUpdated: _loadMedicamentos,
            ),
          ),
        );

        // Se medicamentos foram adicionados, recarregar lista
        if (result == true) {
          _loadMedicamentos();
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Erro ao ${source == ImageSource.camera ? 'capturar' : 'selecionar'} imagem: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    final isFamiliar = familiarState.hasIdosos && widget.idosoId == null;
    
    final content = RefreshIndicator(
      onRefresh: _loadMedicamentos,
      color: Colors.white,
      backgroundColor: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (isFamiliar)
            SliverToBoxAdapter(
              child: const BannerContextoFamiliar(),
            ),
          if (!widget.embedded)
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Medicamentos',
                      style: AppTextStyles.leagueSpartan(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (_isOffline) ...[
                      const SizedBox(width: 8),
                      const OfflineBadge(),
                    ],
                  ],
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFA8B8FF),
                        Color(0xFF9B7EFF),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.medication_liquid,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadMedicamentos,
                ),
              ],
            ),

          SliverToBoxAdapter(
            child: _buildBody(),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    final supabaseService = getIt<SupabaseService>();
    final user = supabaseService.currentUser;
    final userId = user?.id ?? '';

    return OfflineIndicator(
      child: AppScaffoldWithWaves(
        body: Stack(
          children: [
            content,
            if (_isIdoso && userId.isNotEmpty)
              VoiceInterfaceWidget(
                userId: userId,
                showAsFloatingButton: true,
              ),
          ],
        ),
        floatingActionButton: _isIdoso
            ? null
            : FloatingActionButton.extended(
                onPressed: _showAddMedicamentoOptions,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 4,
                icon: const Icon(Icons.add),
                label: Text(
                  'Adicionar',
                  style: AppTextStyles.leagueSpartan(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: ListSkeletonLoader(itemCount: 4, itemHeight: 180),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: ErrorWidgetWithRetry(
          message: _error!,
          onRetry: _loadMedicamentos,
        ),
      );
    }

    if (_medicamentos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.medication_outlined,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Nenhum medicamento encontrado',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Toque no botão "+" para adicionar seu primeiro medicamento e começar a organizar sua saúde',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.leagueSpartan(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                        height: 1.5,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumo dos medicamentos
        Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: AppBorderRadius.xlargeAll,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                        borderRadius: AppBorderRadius.mediumAll,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumo dos Medicamentos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Acompanhe seu tratamento',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
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
                    Expanded(
                      child: _buildSummaryItem(
                        'Total',
                        '${_medicamentos.length}',
                        AppColors.primary,
                        Icons.medication_liquid,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        'Concluídos',
                        '${_medicamentos.where((m) => _isConcluido(m)).length}',
                        const Color(0xFF4CAF50),
                        Icons.check_circle,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        'Pendentes',
                        '${_medicamentos.where((m) => !_isConcluido(m)).length}',
                        const Color(0xFFFF9800),
                        Icons.schedule,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Lista de medicamentos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Text(
                'Seus Medicamentos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _loadMedicamentos,
                child: Text(
                  'Atualizar',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Cards dos medicamentos com animação
        ...(_medicamentos.asMap().entries.map((entry) {
          final index = entry.key;
          final medicamento = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: _buildMedicamentoCard(medicamento)
                .animate()
                .fadeIn(
                  duration: 400.ms,
                  delay: Duration(milliseconds: 50 * index),
                )
                .slideY(
                  begin: 0.1,
                  end: 0,
                  duration: 400.ms,
                  delay: Duration(milliseconds: 50 * index),
                  curve: Curves.easeOutCubic,
                ),
          );
        })),

        SizedBox(height: AppSpacing.bottomNavBarPadding), // Espaço para o FAB e navbar
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicamentoCard(Medicamento medicamento) {
    final concluido = _isConcluido(medicamento);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: AppBorderRadius.xlargeAll,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppBorderRadius.xlargeAll,
          onTap: _isIdoso
              ? () {
                  // Idoso só pode marcar como concluído
                  _toggleConcluido(medicamento);
                }
              : () async {
                  // Outros perfis podem editar
                  // Obter idosoId do FamiliarState se não foi fornecido via widget
                  final familiarState = getIt<FamiliarState>();
                  final idosoId = widget.idosoId ?? 
                      (familiarState.hasIdosos ? familiarState.idosoSelecionado?.id : null);
                  
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditMedicamentoForm(
                        medicamento: medicamento,
                        idosoId: idosoId,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadMedicamentos();
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header do card
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: concluido
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [AppColors.primary, AppColors.primaryLight],
                        ),
                        borderRadius: AppBorderRadius.mediumAll,
                        boxShadow: [
                          BoxShadow(
                            color: (concluido ? Colors.green : AppColors.primary).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        concluido ? Icons.check_circle : Icons.medication,
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
                            medicamento.nome,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: concluido ? Colors.grey.shade600 : Colors.black87,
                              decoration: concluido ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              medicamento.dosagem ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'toggle':
                            _toggleConcluido(medicamento);
                            break;
                          case 'delete':
                            if (!_isIdoso) {
                              _deleteMedicamento(medicamento);
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                concluido ? Icons.undo : Icons.check,
                                size: 20,
                                color: concluido ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Text(concluido ? 'Marcar como pendente' : 'Marcar como concluído'),
                            ],
                          ),
                        ),
                        if (!_isIdoso)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Excluir', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Informações detalhadas
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: AppBorderRadius.mediumAll,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // Frequência
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.schedule,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Frequência',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  medicamento.frequenciaDescricao,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Quantidade
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Estoque',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${medicamento.quantidade ?? 0} unidades',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: (medicamento.quantidade ?? 0) < 10 ? Colors.red.shade600 : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ((medicamento.quantidade ?? 0) < 10)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Estoque baixo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Botão de ação rápida para familiares marcarem como concluído
                if (_isFamiliar && !concluido) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: AppBorderRadius.mediumAll,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleConcluido(medicamento),
                        borderRadius: AppBorderRadius.mediumAll,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Marcar como Tomado',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Botão para desmarcar (se já estiver concluído e for familiar)
                if (_isFamiliar && concluido) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade400,
                      borderRadius: AppBorderRadius.mediumAll,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleConcluido(medicamento),
                        borderRadius: AppBorderRadius.mediumAll,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.undo, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Marcar como Pendente',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}