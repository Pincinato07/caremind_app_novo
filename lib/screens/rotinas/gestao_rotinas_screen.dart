import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/rotina_service.dart';
import '../../services/offline_cache_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/state/familiar_state.dart';
import '../../services/historico_eventos_service.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/banner_contexto_familiar.dart';
import '../../widgets/voice_interface_widget.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/error_widget_with_retry.dart';
import '../../core/feedback/feedback_service.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/rotina_frequencia_widget.dart';
import '../../services/rotina_notification_service.dart';
import '../../widgets/caremind_app_bar.dart'; // Import CareMindAppBar
import 'add_edit_rotina_form.dart';

class GestaoRotinasScreen extends StatefulWidget {
  final String? idosoId;
  final bool embedded;

  const GestaoRotinasScreen({
    super.key,
    this.idosoId,
    this.embedded = false,
  });

  @override
  State<GestaoRotinasScreen> createState() => _GestaoRotinasScreenState();
}

class _GestaoRotinasScreenState extends State<GestaoRotinasScreen> {
  List<Map<String, dynamic>> _rotinas = [];
  bool _isLoading = true;
  String? _error;
  String? _perfilTipo;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadRotinas();

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
          _loadRotinas();
          if (mounted) {
            FeedbackService.showSuccess(context, 'Conexão restaurada!');
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
    // Recarregar rotinas quando o idoso selecionado mudar
    if (mounted && widget.idosoId == null) {
      _loadRotinas();
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
  bool get _isFamiliar {
    final familiarState = getIt<FamiliarState>();
    return familiarState.hasIdosos && widget.idosoId == null;
  }

  Future<void> _loadRotinas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final isOnline = await OfflineCacheService.isOnline();
    setState(() => _isOffline = !isOnline);

    try {
      final supabaseService = getIt<SupabaseService>();
      final rotinaService = getIt<RotinaService>();
      final user = supabaseService.currentUser;

      if (user != null) {
        final familiarState = getIt<FamiliarState>();
        final targetId = widget.idosoId ??
            (familiarState.hasIdosos && familiarState.idosoSelecionado != null
                ? familiarState.idosoSelecionado!.id
                : user.id);

        if (isOnline) {
          final rotinas = await rotinaService.getRotinas(targetId);

          await OfflineCacheService.cacheRotinas(targetId, rotinas);

          // Agendar notificações para todas as rotinas
          for (final rotina in rotinas) {
            try {
              await RotinaNotificationService.scheduleRotinaNotifications(rotina);
            } catch (e) {
              debugPrint('⚠️ Erro ao agendar notificação para rotina ${rotina['id']}: $e');
            }
          }

          setState(() {
            _rotinas = rotinas;
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
            : 'Erro ao carregar rotinas: $error';
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFromCache(String userId) async {
    try {
      final cachedRotinas = await OfflineCacheService.getCachedRotinas(userId);

      if (cachedRotinas.isNotEmpty) {
        setState(() {
          _rotinas = cachedRotinas;
          _isLoading = false;
          _isOffline = true;
        });

        if (mounted) {
          FeedbackService.showWarning(
              context, 'Usando dados salvos (modo offline)');
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

  Future<void> _toggleConcluida(Map<String, dynamic> rotina) async {
    try {
      final rotinaService = getIt<RotinaService>();
      final supabaseService = getIt<SupabaseService>();
      final familiarState = getIt<FamiliarState>();

      final rotinaId = rotina['id'] as int;
      final concluida = rotina['concluido'] as bool? ?? false;
      final titulo = rotina['titulo'] as String? ?? 'Rotina';
      final novoEstado = !concluida;

      // Determinar o perfil_id do idoso (não do familiar)
      final user = supabaseService.currentUser;
      if (user == null) return;

      // Se for familiar gerenciando idoso, usar o id do idoso; senão usar o user.id
      final targetPerfilId = widget.idosoId ??
          (familiarState.hasIdosos && familiarState.idosoSelecionado != null
              ? familiarState.idosoSelecionado!.id
              : user.id);

      // Atualizar a rotina
      await rotinaService.toggleConcluida(rotinaId, novoEstado);

      // Registrar evento no histórico
      try {
        await HistoricoEventosService.addEvento({
          'perfil_id': targetPerfilId,
          'tipo_evento': novoEstado ? 'rotina_concluida' : 'rotina_desmarcada',
          'data_hora': DateTime.now().toIso8601String(),
          'descricao': novoEstado
              ? 'Rotina "$titulo" marcada como concluída'
              : 'Rotina "$titulo" desmarcada',
          'referencia_id': rotinaId.toString(),
          'tipo_referencia': 'rotina',
        });
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        debugPrint('⚠️ Erro ao registrar evento no histórico: $e');
      }

      _loadRotinas();
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao atualizar rotina: $error';
      _showError(errorMessage);
    }
  }

  Future<void> _deleteRotina(Map<String, dynamic> rotina) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
            'Deseja realmente excluir a rotina "${rotina['titulo'] ?? 'Rotina'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final rotinaService = getIt<RotinaService>();
        await rotinaService.deleteRotina(rotina['id'] as int);
        _loadRotinas();
        _showSuccess('Rotina excluída com sucesso');
      } catch (error) {
        final errorMessage = error is AppException
            ? error.message
            : 'Erro ao excluir rotina: $error';
        _showError(errorMessage);
      }
    }
  }

  void _showError(String message) {
    FeedbackService.showError(context, UnknownException(message: message),
        onRetry: _loadRotinas);
  }

  void _showSuccess(String message) {
    FeedbackService.showSuccess(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    final isFamiliar = familiarState.hasIdosos && widget.idosoId == null;

    final content = RefreshIndicator(
      onRefresh: _loadRotinas,
      color: Colors.white,
      backgroundColor: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (isFamiliar)
              const BannerContextoFamiliar(),
            _buildBody(),
          ],
        ),
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
        appBar: CareMindAppBar(
          title: 'Rotinas',
          showBackButton: !_isIdoso, // Back button only if not main persistent tab (usually Idoso treats this as a main tab/screen? No context, assuming yes if not embedded)
          // Adjust logic based on navigation flow. If it's a main tab, no back. 
          // Assuming GestaoRotinasScreen can be pushed.
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRotinas,
            ),
          ],
        ),
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
                onPressed: () async {
                  final familiarState = getIt<FamiliarState>();
                  final idosoId = widget.idosoId ??
                      (familiarState.hasIdosos
                          ? familiarState.idosoSelecionado?.id
                          : null);

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditRotinaForm(idosoId: idosoId),
                    ),
                  );
                  if (result == true) {
                    _loadRotinas();
                  }
                },
                backgroundColor: AppColors.primary,
                elevation: 4,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Adicionar',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16),
                ),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.large),
        child: ListSkeletonLoader(itemCount: 4, itemHeight: 140),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: ErrorWidgetWithRetry(
          message: _error!,
          onRetry: _loadRotinas,
        ),
      );
    }

    if (_rotinas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.large),
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
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.primaryLight.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: AppBorderRadius.xlargeAll,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          AppColors.primary,
                          AppColors.primaryLight
                        ]),
                        borderRadius: AppBorderRadius.largeAll,
                      ),
                      child: const Icon(Icons.schedule,
                          size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Nenhuma rotina encontrada',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isIdoso
                          ? 'Suas rotinas aparecerão aqui'
                          : 'Toque no botão "+" para adicionar sua primeira rotina',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          height: 1.5),
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
        Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  AppColors.primary.withValues(alpha: 0.02)
                ],
              ),
              borderRadius: BorderRadius.circular(AppBorderRadius.xlarge),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  width: 1),
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
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  ),
                  child: const Icon(Icons.analytics_outlined,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total de Rotinas',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('${_rotinas.length} rotina(s)',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
          child: Text('Suas Rotinas',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(height: AppSpacing.medium),
        ...(_rotinas.asMap().entries.map((entry) {
          final index = entry.key;
          final rotina = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large, vertical: 8),
            child: _buildRotinaCard(rotina)
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
        const SizedBox(height: AppSpacing.bottomNavBarPadding),
      ],
    );
  }

  // Usar o widget de frequência em vez de função local
  String _formatarFrequencia(Map<String, dynamic>? frequencia) {
    // Delegar para o widget (mantido para compatibilidade)
    return RotinaFrequenciaWidget.formatarFrequencia(frequencia);
  }

  Widget _buildRotinaCard(Map<String, dynamic> rotina) {
    final concluida = rotina['concluido'] as bool? ?? false;
    final titulo = rotina['titulo'] as String? ?? 'Rotina';
    final descricao = rotina['descricao'] as String?;
    final frequencia = rotina['frequencia'] as Map<String, dynamic>?;
    final frequenciaTexto = _formatarFrequencia(frequencia);
    
    // Extrair horário para exibição simples (primeiro horário se diário)
    String? horario;
    if (frequencia != null) {
      if (frequencia['tipo'] == 'diario' && frequencia['horarios'] != null) {
        final horarios = frequencia['horarios'] as List?;
        if (horarios != null && horarios.isNotEmpty) {
          horario = horarios[0] as String;
        }
      } else if (frequencia['horario'] != null) {
        horario = frequencia['horario'] as String;
      } else if (frequencia['inicio'] != null) {
        horario = frequencia['inicio'] as String;
      }
    }
    // Fallback para campo horario legado (se existir)
    if (horario == null) {
      horario = rotina['horario'] as String?;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.xlarge),
        border: Border.all(
          color: concluida
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.1),
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
          borderRadius: BorderRadius.circular(AppBorderRadius.xlarge),
          onTap: _isIdoso
              ? () => _toggleConcluida(rotina)
              : () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        // Obter idosoId do FamiliarState se não foi fornecido via widget
                        final familiarState = getIt<FamiliarState>();
                        final idosoId = widget.idosoId ??
                            (familiarState.hasIdosos
                                ? familiarState.idosoSelecionado?.id
                                : null);
                        return AddEditRotinaForm(
                            rotina: rotina, idosoId: idosoId);
                      },
                    ),
                  );
                  if (result == true) {
                    _loadRotinas();
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
                        color: concluida
                              ? AppColors.success
                              : AppColors.primary,
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      ),
                      child: Icon(
                        concluida ? Icons.check_circle : Icons.schedule,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: concluida
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration:
                                  concluida ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RotinaFrequenciaWidget(
                            frequencia: frequencia,
                            showIcon: true,
                            textStyle: TextStyle(
                              fontSize: 14,
                              color: concluida
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (frequenciaTexto.isEmpty && horario != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Horário: $horario',
                              style: TextStyle(
                                fontSize: 14,
                                color: concluida
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!_isIdoso)
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.more_vert,
                              color: Colors.grey, size: 20),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'toggle':
                              _toggleConcluida(rotina);
                              break;
                            case 'delete':
                              _deleteRotina(rotina);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  concluida ? Icons.undo : Icons.check,
                                  size: 20,
                                  color:
                                      concluida ? AppColors.warning : AppColors.success,
                                ),
                                const SizedBox(width: 12),
                                Text(concluida
                                    ? 'Marcar como pendente'
                                    : 'Marcar como concluída'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 20, color: AppColors.error),
                                SizedBox(width: 12),
                                Text('Excluir',
                                    style: TextStyle(color: AppColors.error)),
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
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      descricao,
                      style:
                          const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ],

                // Botão de ação rápida para familiares marcarem como concluída
                if (_isFamiliar && !concluida) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleConcluida(rotina),
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Marcar como Concluída',
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

                // Botão para desmarcar (se já estiver concluída e for familiar)
                if (_isFamiliar && concluida) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleConcluida(rotina),
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.undo,
                                  color: Colors.white, size: 24),
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
