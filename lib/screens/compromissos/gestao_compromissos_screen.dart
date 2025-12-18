import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/compromisso_service.dart';
import '../../services/offline_cache_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/state/familiar_state.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/banner_contexto_familiar.dart';
import '../../widgets/compromissos_calendar.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/error_widget_with_retry.dart';
import '../../widgets/feedback_snackbar.dart';
import '../../widgets/offline_indicator.dart';
import 'add_edit_compromisso_form.dart';

class GestaoCompromissosScreen extends StatefulWidget {
  final String? idosoId;
  final bool embedded;

  const GestaoCompromissosScreen({
    super.key,
    this.idosoId,
    this.embedded = false,
  });

  @override
  State<GestaoCompromissosScreen> createState() => _GestaoCompromissosScreenState();
}

class _GestaoCompromissosScreenState extends State<GestaoCompromissosScreen> {
  List<Map<String, dynamic>> _compromissos = [];
  bool _isLoading = true;
  String? _error;
  String? _perfilTipo;
  String _viewMode = 'list';
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadCompromissos();
    
    final familiarState = getIt<FamiliarState>();
    familiarState.addListener(_onFamiliarStateChanged);
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    OfflineCacheService.connectivityStream.listen((isOnline) {
      if (mounted) {
        final wasOffline = _isOffline;
        setState(() => _isOffline = !isOnline);
        
        if (wasOffline && isOnline) {
          _loadCompromissos();
          if (mounted) {
            FeedbackSnackbar.success(context, 'Conexão restaurada!');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    final familiarState = getIt<FamiliarState>();
    familiarState.removeListener(_onFamiliarStateChanged);
    super.dispose();
  }

  void _onFamiliarStateChanged() {
    // Recarregar compromissos quando o idoso selecionado mudar
    if (mounted && widget.idosoId == null) {
      _loadCompromissos();
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
      // Ignora erro
    }
  }

  bool get _isIdoso => _perfilTipo == 'idoso';

  Future<void> _loadCompromissos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final isOnline = await OfflineCacheService.isOnline();
    setState(() => _isOffline = !isOnline);

    try {
      final supabaseService = getIt<SupabaseService>();
      final compromissoService = getIt<CompromissoService>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        final familiarState = getIt<FamiliarState>();
        final targetId = widget.idosoId ?? 
            (familiarState.hasIdosos && familiarState.idosoSelecionado != null 
                ? familiarState.idosoSelecionado!.id 
                : user.id);
        
        if (isOnline) {
          final compromissos = await compromissoService.getCompromissos(targetId);
          
          await OfflineCacheService.cacheCompromissos(targetId, compromissos);
          
          setState(() {
            _compromissos = compromissos;
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
            : 'Erro ao carregar compromissos: $error';
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFromCache(String userId) async {
    try {
      final cachedCompromissos = await OfflineCacheService.getCachedCompromissos(userId);
      
      if (cachedCompromissos.isNotEmpty) {
        setState(() {
          _compromissos = cachedCompromissos;
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

  Future<void> _deleteCompromisso(Map<String, dynamic> compromisso) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o compromisso "${compromisso['titulo'] ?? 'Compromisso'}"?'),
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
        final compromissoService = getIt<CompromissoService>();
        await compromissoService.deleteCompromisso(compromisso['id'] as String);
        _loadCompromissos();
        _showSuccess('Compromisso excluído com sucesso');
      } catch (error) {
        final errorMessage = error is AppException
            ? error.message
            : 'Erro ao excluir compromisso: $error';
        _showError(errorMessage);
      }
    }
  }

  void _showError(String message) {
    FeedbackSnackbar.error(context, message, onRetry: _loadCompromissos);
  }

  void _showSuccess(String message) {
    FeedbackSnackbar.success(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    final isFamiliar = familiarState.hasIdosos && widget.idosoId == null;
    
    final content = RefreshIndicator(
      onRefresh: _loadCompromissos,
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
                      'Compromissos',
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
                      colors: [Color(0xFFA8B8FF), Color(0xFF9B7EFF)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.calendar_today, size: 48, color: Colors.white),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadCompromissos,
                ),
              ],
            ),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return OfflineIndicator(
      child: AppScaffoldWithWaves(
        body: content,
        floatingActionButton: _isIdoso
            ? null
            : FloatingActionButton.extended(
                onPressed: () async {
                  final familiarState = getIt<FamiliarState>();
                  final idosoId = widget.idosoId ?? 
                      (familiarState.hasIdosos ? familiarState.idosoSelecionado?.id : null);
                  
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditCompromissoForm(idosoId: idosoId),
                    ),
                  );
                  if (result == true) {
                    _loadCompromissos();
                  }
                },
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
      ),
    );
  }

  Widget _buildBody() {
    // Toggle entre lista e calendário (só mostra se houver compromissos)
    final showToggle = !_isLoading && _error == null && _compromissos.isNotEmpty;
    
    if (showToggle) {
      return Column(
        children: [
          // Toggle de visualização
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewToggleButton('list', Icons.list, 'Lista'),
                _buildViewToggleButton('calendar', Icons.calendar_today, 'Calendário'),
              ],
            ),
          ),
          
          // Conteúdo baseado no modo de visualização
          Expanded(
            child: _viewMode == 'calendar'
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: CompromissosCalendar(
                      compromissos: _compromissos,
                      onCompromissoTap: (compromisso) async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              final familiarState = getIt<FamiliarState>();
                              final idosoId = widget.idosoId ?? 
                                  (familiarState.hasIdosos ? familiarState.idosoSelecionado?.id : null);
                              return AddEditCompromissoForm(compromisso: compromisso, idosoId: idosoId);
                            },
                          ),
                        );
                        if (result == true) {
                          _loadCompromissos();
                        }
                      },
                    ),
                  )
                : _buildListView(),
          ),
        ],
      );
    }
    
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: ListSkeletonLoader(itemCount: 4, itemHeight: 140),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: ErrorWidgetWithRetry(
          message: _error!,
          onRetry: _loadCompromissos,
        ),
      );
    }

    if (_compromissos.isEmpty) {
      return SingleChildScrollView(
        child: Container(
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
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
                      ),
                      child: const Icon(Icons.calendar_today, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Nenhum compromisso encontrado',
                      style: AppTextStyles.leagueSpartan(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isIdoso
                          ? 'Seus compromissos aparecerão aqui'
                          : 'Toque no botão "+" para adicionar seu primeiro compromisso',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      );
    }

    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, AppColors.primary.withValues(alpha: 0.02)],
              ),
              borderRadius: AppBorderRadius.xlargeAll,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                    borderRadius: AppBorderRadius.mediumAll,
                  ),
                  child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total de Compromissos',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_compromissos.length} compromisso(s)',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Seus Compromissos',
            style: AppTextStyles.leagueSpartan(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...(_compromissos.map((compromisso) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildCompromissoCard(compromisso),
            ))),
        SizedBox(height: AppSpacing.bottomNavBarPadding),
      ],
    ),
    );
  }

  Widget _buildViewToggleButton(String mode, IconData icon, String label) {
    final isActive = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _viewMode = mode;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  )
                : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: AppBorderRadius.smallAll,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.leagueSpartan(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Seus Compromissos',
              style: AppTextStyles.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...(_compromissos.asMap().entries.map((entry) {
            final index = entry.key;
            final compromisso = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildCompromissoCard(compromisso)
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
          SizedBox(height: AppSpacing.bottomNavBarPadding),
        ],
      ),
    );
  }

  Widget _buildCompromissoCard(Map<String, dynamic> compromisso) {
    final dataHora = DateTime.parse(compromisso['data_hora'] as String);
    final titulo = compromisso['titulo'] as String? ?? 'Compromisso';
    final descricao = compromisso['descricao'] as String?;
    final isPassado = dataHora.isBefore(DateTime.now());

    return Container(
      decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPassado
                    ? Colors.red.shade300
                    : Colors.white.withValues(alpha: 0.2),
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
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        final familiarState = getIt<FamiliarState>();
                        final idosoId = widget.idosoId ?? 
                            (familiarState.hasIdosos ? familiarState.idosoSelecionado?.id : null);
                        return AddEditCompromissoForm(compromisso: compromisso, idosoId: idosoId);
                      },
                    ),
                  );
                  if (result == true) {
                    _loadCompromissos();
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPassado
                              ? [Colors.red.shade400, Colors.red.shade600]
                              : [AppColors.primary, AppColors.primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPassado ? Icons.event_busy : Icons.calendar_today,
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
                            titulo,
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dataHora.day}/${dataHora.month}/${dataHora.year} às ${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isIdoso)
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: AppBorderRadius.smallAll,
                          ),
                          child: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'delete':
                              _deleteCompromisso(compromisso);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
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
                if (descricao != null && descricao.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      descricao,
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
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
