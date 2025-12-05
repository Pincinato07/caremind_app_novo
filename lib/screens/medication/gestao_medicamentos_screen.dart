import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/medicamento.dart';
import '../../services/medicamento_service.dart';
import '../../services/supabase_service.dart';
import '../../services/accessibility_service.dart';
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
  bool _isLoading = true;
  String? _error;
  String? _perfilTipo; // Tipo do perfil do usuário

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadMedicamentos();
    
    // Escutar mudanças no FamiliarState para recarregar quando o idoso mudar
    final familiarState = getIt<FamiliarState>();
    familiarState.addListener(_onFamiliarStateChanged);
    
    // Inicializa o serviço de acessibilidade
    AccessibilityService.initialize();
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

  Future<void> _loadMedicamentos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseService = getIt<SupabaseService>();
      final medicamentoService = getIt<MedicamentoService>();
      final familiarState = getIt<FamiliarState>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        // Prioridade: widget.idosoId > FamiliarState.idosoSelecionado > user.id
        final targetId = widget.idosoId ?? 
            (familiarState.hasIdosos && familiarState.idosoSelecionado != null 
                ? familiarState.idosoSelecionado!.id 
                : user.id);
        
        final medicamentos = await medicamentoService.getMedicamentos(targetId);
        setState(() {
          _medicamentos = medicamentos;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Usuário não encontrado';
          _isLoading = false;
        });
      }
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao carregar medicamentos: $error';
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleConcluido(Medicamento medicamento) async {
    try {
      final medicamentoService = getIt<MedicamentoService>();
      final supabaseService = getIt<SupabaseService>();
      final familiarState = getIt<FamiliarState>();
      
      // Determinar o perfil_id do idoso (não do familiar)
      final user = supabaseService.currentUser;
      if (user == null) return;
      
      // Se for familiar gerenciando idoso, usar o id do idoso; senão usar o user.id
      final targetPerfilId = widget.idosoId ?? 
          (familiarState.hasIdosos && familiarState.idosoSelecionado != null 
              ? familiarState.idosoSelecionado!.id 
              : user.id);
      
      
      // Atualizar o medicamento
      await medicamentoService.toggleConcluido(
        medicamento.id!,
        true, // sempre marcando como concluído quando chamado
        DateTime.now(), // data prevista
      );
      
      // Registrar evento no histórico
      try {
        await HistoricoEventosService.addEvento({
          'perfil_id': targetPerfilId,
          'tipo_evento': 'medicamento_tomado',
          'evento_id': medicamento.id!,
          'data_prevista': DateTime.now().toIso8601String(),
          'status': 'concluido',
          'titulo': medicamento.nome,
          'descricao': 'Medicamento "${medicamento.nome}" marcado como tomado',
          'medicamento_id': medicamento.id!,
        });
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        debugPrint('⚠️ Erro ao registrar evento no histórico: $e');
      }
      
      _loadMedicamentos(); // Recarrega a lista
    } catch (error) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Mostra diálogo com opções: Formulário ou OCR
  Future<void> _showAddMedicamentoOptions() async {
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
                          borderRadius: BorderRadius.circular(12),
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
                GlassCard(
                  onTap: () => Navigator.pop(context, 'ocr'),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(12),
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
    
    final content = CustomScrollView(
      slivers: [
        // Banner de contexto para perfil familiar
        if (isFamiliar)
          SliverToBoxAdapter(
            child: const BannerContextoFamiliar(),
          ),
        // Header moderno - apenas se não estiver embedded
        if (!widget.embedded)
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Medicamentos',
                style: AppTextStyles.leagueSpartan(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
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

        // Conteúdo principal
        SliverToBoxAdapter(
          child: _buildBody(),
        ),
      ],
    );

    if (widget.embedded) {
      // Modo embedded: retorna apenas o conteúdo, sem AppScaffoldWithWaves
      return content;
    }

    // Modo standalone: retorna com AppScaffoldWithWaves e FAB
    final supabaseService = getIt<SupabaseService>();
    final user = supabaseService.currentUser;
    final userId = user?.id ?? '';

    return AppScaffoldWithWaves(
      body: Stack(
        children: [
          content,
          // Interface de voz para idosos
          if (_isIdoso && userId.isNotEmpty)
            VoiceInterfaceWidget(
              userId: userId,
              showAsFloatingButton: true,
            ),
        ],
      ),
      floatingActionButton: _isIdoso
          ? null // Idoso não pode adicionar medicamentos
          : FloatingActionButton.extended(
              onPressed: _showAddMedicamentoOptions,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0400BA),
              elevation: 4,
              icon: const Icon(Icons.add),
              label: Text(
                'Adicionar',
                style: AppTextStyles.leagueSpartan(
                  color: const Color(0xFF0400BA),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'Carregando medicamentos...',
                style: AppTextStyles.leagueSpartan(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar medicamentos',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.leagueSpartan(
                        color: Colors.red.shade300,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadMedicamentos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0400BA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Tentar novamente',
                        style: AppTextStyles.leagueSpartan(
                          fontWeight: FontWeight.w700,
                        ),
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
                  const Color(0xFF0400B9).withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF0400B9).withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0400B9).withValues(alpha: 0.1),
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
                          colors: [Color(0xFF0400B9), Color(0xFF0600E0)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0400B9).withValues(alpha: 0.3),
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
                        const Color(0xFF0400B9),
                        Icons.medication_liquid,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        'Concluídos',
                        '${_medicamentos.where((m) => m.concluido).length}',
                        const Color(0xFF4CAF50),
                        Icons.check_circle,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        'Pendentes',
                        '${_medicamentos.where((m) => !m.concluido).length}',
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
                    color: const Color(0xFF0400B9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Cards dos medicamentos
        ...(_medicamentos.map((medicamento) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildMedicamentoCard(medicamento),
            ))),

        const SizedBox(height: 100), // Espaço para o FAB e navbar
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFF0400B9).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0400B9).withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0400B9).withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
                          colors: medicamento.concluido
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [const Color(0xFF0400B9), const Color(0xFF0600E0)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (medicamento.concluido ? Colors.green : const Color(0xFF0400B9)).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        medicamento.concluido ? Icons.check_circle : Icons.medication,
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
                              color: medicamento.concluido ? Colors.grey.shade600 : Colors.black87,
                              decoration: medicamento.concluido ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0400B9).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              medicamento.dosagem,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0400B9),
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
                                medicamento.concluido ? Icons.undo : Icons.check,
                                size: 20,
                                color: medicamento.concluido ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Text(medicamento.concluido ? 'Marcar como pendente' : 'Marcar como concluído'),
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
                    borderRadius: BorderRadius.circular(12),
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
                                  '${medicamento.quantidade} unidades',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: medicamento.quantidade < 10 ? Colors.red.shade600 : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (medicamento.quantidade < 10)
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
                if (_isFamiliar && !medicamento.concluido) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
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
                if (_isFamiliar && medicamento.concluido) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade400,
                      borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
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
