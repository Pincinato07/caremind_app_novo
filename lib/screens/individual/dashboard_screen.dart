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
import '../../widgets/offline_indicator.dart';
import '../../widgets/undo_snackbar.dart';
import '../../widgets/recent_actions_panel.dart';
import '../../widgets/quick_action_fab.dart';
import '../../widgets/batch_medication_selector.dart';
import '../../services/notification_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/empty_state.dart';
import '../medication/gestao_medicamentos_screen.dart';
import '../medication/add_edit_medicamento_form.dart';

class IndividualDashboardScreen extends StatefulWidget {
  const IndividualDashboardScreen({super.key});

  @override
  State<IndividualDashboardScreen> createState() =>
      _IndividualDashboardScreenState();
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
  bool _isSelectionMode = false;
  List<MedicationAction> _recentActions = [];
  Map<int, bool> _syncingMedicamentos = {}; // Estado de sincronização

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
          _syncPendingActionsWithFeedback();
          _loadUserData();
        }
      }
    });
  }

  Future<void> _syncPendingActionsWithFeedback() async {
    try {
      final pendingActions = await OfflineCacheService.getPendingActions();
      if (pendingActions.isEmpty) return;

      if (mounted) {
        try {
          FeedbackSnackbar.info(context,
              'Conexão restaurada! Sincronizando ${pendingActions.length} ação(ões)...');
        } catch (e) {
          debugPrint('⚠️ Erro ao mostrar feedback de sincronização: $e');
        }
      }

      int synced = 0;
      int failed = 0;

      for (final action in pendingActions) {
        try {
          if (action['type'] == 'toggle_medicamento') {
            final medicamentoId = action['medicamento_id'] as int?;
            if (medicamentoId == null) {
              debugPrint('⚠️ Ação pendente sem medicamento_id válido');
              failed++;
              continue;
            }

            // Marcar como sincronizando
            if (mounted) {
              try {
                setState(() {
                  _syncingMedicamentos[medicamentoId] = true;
                });
              } catch (e) {
                debugPrint('⚠️ Erro ao atualizar estado de sincronização: $e');
              }
            }

            try {
              final medicamentoService = getIt<MedicamentoService>();
              final dataStr = action['data'] as String?;
              if (dataStr == null) {
                throw Exception('Data não encontrada na ação pendente');
              }

              await medicamentoService.toggleConcluido(
                medicamentoId,
                action['concluido'] as bool? ?? true,
                DateTime.parse(dataStr),
              );

              synced++;
            } catch (e, stackTrace) {
              debugPrint(
                  '❌ Erro ao sincronizar ação pendente para medicamento $medicamentoId: $e');
              debugPrint('Stack trace: $stackTrace');
              failed++;
            } finally {
              // Remover estado de sincronização
              if (mounted) {
                try {
                  setState(() {
                    _syncingMedicamentos[medicamentoId] = false;
                  });
                } catch (e) {
                  debugPrint('⚠️ Erro ao remover estado de sincronização: $e');
                }
              }
            }
          } else {
            debugPrint(
                '⚠️ Tipo de ação pendente desconhecido: ${action['type']}');
            failed++;
          }
        } catch (e, stackTrace) {
          debugPrint('❌ Erro ao processar ação pendente: $e');
          debugPrint('Stack trace: $stackTrace');
          failed++;
        }
      }

      // Limpar ações sincronizadas com sucesso
      if (synced > 0) {
        try {
          await OfflineCacheService.clearPendingActions();
        } catch (e) {
          debugPrint('⚠️ Erro ao limpar ações pendentes: $e');
        }
      }

      if (mounted) {
        try {
          if (failed == 0) {
            FeedbackSnackbar.success(
                context, '$synced ação(ões) sincronizada(s) com sucesso!');
          } else {
            FeedbackSnackbar.warning(context,
                '$synced sincronizada(s), $failed falharam. Tente novamente.');
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao mostrar feedback final de sincronização: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao sincronizar ações pendentes: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        try {
          FeedbackSnackbar.error(
              context, 'Erro ao sincronizar ações pendentes');
        } catch (e2) {
          debugPrint('⚠️ Erro ao mostrar feedback de erro: $e2');
        }
      }
    }
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
      final cachedMedicamentos =
          await OfflineCacheService.getCachedMedicamentos(userId);
      final cachedRotinas = await OfflineCacheService.getCachedRotinas(userId);
      _lastSync =
          await OfflineCacheService.getCacheTimestamp(userId, 'medicamentos');

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
          FeedbackSnackbar.warning(
              context, 'Usando dados salvos (modo offline)');
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

  Future<void> _loadDashboardData(
      String userId, SupabaseService supabaseService) async {
    try {
      final medicamentoService = getIt<MedicamentoService>();
      final rotinaService = getIt<RotinaService>();

      final medicamentosResult =
          await medicamentoService.getMedicamentos(userId);

      // Extrair lista de medicamentos do Result
      final medicamentos = medicamentosResult.when(
        success: (data) => data,
        failure: (exception) {
          debugPrint('Erro ao carregar medicamentos: ${exception.message}');
          return <Medicamento>[];
        },
      );

      // Salvar no cache offline
      await OfflineCacheService.cacheMedicamentos(userId, medicamentos);

      Map<int, bool> statusMedicamentos = {};
      if (medicamentos.isNotEmpty) {
        final ids =
            medicamentos.where((m) => m.id != null).map((m) => m.id!).toList();
        statusMedicamentos =
            await HistoricoEventosService.checkMedicamentosConcluidosHoje(
                userId, ids);
      }

      _statusMedicamentos = statusMedicamentos;
      _totalMedicamentos = medicamentos.length;
      _medicamentosTomados =
          medicamentos.where((m) => statusMedicamentos[m.id] ?? false).length;

      _proximoMedicamento =
          _calcularProximoMedicamento(medicamentos, statusMedicamentos);
      _medicamentosPendentes = medicamentos
          .where((m) => !(statusMedicamentos[m.id] ?? false))
          .toList();

      final rotinas = await rotinaService.getRotinas(userId);
      _rotinas = rotinas;

      // Salvar rotinas no cache
      await OfflineCacheService.cacheRotinas(userId, rotinas);

      final pendentes = medicamentos
          .where((m) => !(statusMedicamentos[m.id] ?? false))
          .toList();
      if (pendentes.isEmpty) {
        _temAtraso = false;
        _mensagemStatus = 'Você tomou tudo hoje.';
      } else {
        _temAtraso = true;
        _mensagemStatus =
            'Você tem ${pendentes.length} medicamento(s) pendente(s).';
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

    final medicamentoId = medicamento.id!;
    final isCurrentlyTaken = _statusMedicamentos[medicamentoId] ?? false;

    // Verificar conexão antes de tentar
    final isOnline = await OfflineCacheService.isOnline();

    setState(() {
      _loadingMedicamentos[medicamentoId] = true;
      _syncingMedicamentos[medicamentoId] = false;
    });

    // Atualizar UI imediatamente (optimistic update)
    setState(() {
      _statusMedicamentos[medicamentoId] = !isCurrentlyTaken;
      _loadingMedicamentos[medicamentoId] = false;

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
      if (!isOnline) {
        // Salvar ação para sincronizar depois
        await OfflineCacheService.addPendingAction({
          'type': 'toggle_medicamento',
          'medicamento_id': medicamentoId,
          'concluido': !isCurrentlyTaken,
          'data': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          FeedbackSnackbar.info(
              context, 'Salvo offline. Será sincronizado quando conectar.');
        }
      } else {
        // Mostrar estado de sincronização
        if (mounted) {
          setState(() {
            _syncingMedicamentos[medicamentoId] = true;
          });
        }

        final medicamentoService = getIt<MedicamentoService>();
        await medicamentoService.toggleConcluido(
          medicamentoId,
          !isCurrentlyTaken,
          DateTime.now(),
        );

        // Se medicamento foi marcado como tomado, cancelar notificações e snoozes
        if (!isCurrentlyTaken && medicamento.id != null) {
          try {
            await NotificationService.confirmMedication(medicamento.id!);
          } catch (e) {
            debugPrint('⚠️ Dashboard: Erro ao cancelar notificações - $e');
            // Não é crítico, continuar mesmo se falhar
          }
        }

        // Remover estado de sincronização
        if (mounted) {
          setState(() {
            _syncingMedicamentos[medicamentoId] = false;
          });
        }

        // Adicionar à lista de ações recentes
        if (!isCurrentlyTaken) {
          _addRecentAction(medicamento, DateTime.now(), true);

          if (mounted) {
            UndoSnackbar.show(
              context,
              message: '${medicamento.nome} marcado como tomado!',
              onUndo: () => _confirmarMedicamento(medicamento),
              duration: const Duration(seconds: 15),
            );
          }
        } else {
          _addRecentAction(medicamento, DateTime.now(), false);
          if (mounted) {
            FeedbackSnackbar.info(context, '${medicamento.nome} desmarcado');
          }
        }
      }
    } catch (e) {
      debugPrint(
          '❌ Dashboard: Erro ao confirmar medicamento ${medicamento.nome} - $e');

      // Remover estados de loading/sincronização
      if (mounted) {
        setState(() {
          _loadingMedicamentos[medicamentoId] = false;
          _syncingMedicamentos[medicamentoId] = false;
        });
      }

      // Tentar determinar se é erro de rede ou outro
      bool isNetworkError = false;
      try {
        final stillOffline = !(await OfflineCacheService.isOnline());
        if (stillOffline) {
          isNetworkError = true;
        }
      } catch (_) {
        // Se não conseguir verificar, assumir erro de rede
        isNetworkError = true;
      }

      if (isNetworkError) {
        // Se está offline, tentar salvar como pendente
        try {
          await OfflineCacheService.addPendingAction({
            'type': 'toggle_medicamento',
            'medicamento_id': medicamentoId,
            'concluido': !isCurrentlyTaken,
            'data': DateTime.now().toIso8601String(),
          });

          if (mounted) {
            FeedbackSnackbar.info(
                context, 'Salvo offline. Será sincronizado quando conectar.');
          }
        } catch (saveError) {
          debugPrint('❌ Dashboard: Erro ao salvar ação offline - $saveError');
          // Reverter mudança se não conseguir salvar offline
          if (mounted) {
            setState(() {
              _statusMedicamentos[medicamentoId] = isCurrentlyTaken;
              if (!isCurrentlyTaken) {
                _medicamentosTomados--;
                _medicamentosPendentes.add(medicamento);
              } else {
                _medicamentosTomados++;
                _medicamentosPendentes
                    .removeWhere((m) => m.id == medicamento.id);
              }
              _temAtraso = _medicamentosPendentes.isNotEmpty;
              _mensagemStatus = _temAtraso
                  ? 'Você tem ${_medicamentosPendentes.length} medicamento(s) pendente(s).'
                  : 'Você tomou tudo hoje.';
            });

            FeedbackSnackbar.error(
              context,
              'Erro ao salvar. Verifique sua conexão.',
              onRetry: () => _confirmarMedicamento(medicamento),
            );
          }
        }
      } else {
        // Erro não relacionado a rede, reverter mudança
        if (mounted) {
          setState(() {
            _statusMedicamentos[medicamentoId] = isCurrentlyTaken;
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

          FeedbackSnackbar.error(
            context,
            'Erro ao atualizar medicamento: ${e.toString()}',
            onRetry: () => _confirmarMedicamento(medicamento),
          );
        }
      }
    }
  }

  void _addRecentAction(
      Medicamento medicamento, DateTime timestamp, bool isConfirmed) {
    try {
      if (medicamento.id == null || medicamento.id! <= 0) {
        debugPrint(
            '⚠️ Dashboard: Tentativa de adicionar ação recente com ID inválido');
        return;
      }

      if (medicamento.nome.isEmpty) {
        debugPrint(
            '⚠️ Dashboard: Tentativa de adicionar ação recente sem nome');
        return;
      }

      setState(() {
        _recentActions.insert(
            0,
            MedicationAction(
              medicationId: medicamento.id!,
              medicationName: medicamento.nome,
              timestamp: timestamp,
              isConfirmed: isConfirmed,
              onUndo: () {
                try {
                  _confirmarMedicamento(medicamento);
                } catch (e) {
                  debugPrint('❌ Dashboard: Erro ao desfazer ação recente - $e');
                  if (mounted) {
                    FeedbackSnackbar.error(context, 'Erro ao desfazer ação');
                  }
                }
              },
            ));

        // Manter apenas as últimas 10 ações
        if (_recentActions.length > 10) {
          _recentActions = _recentActions.take(10).toList();
        }
      });
    } catch (e) {
      debugPrint('❌ Dashboard: Erro ao adicionar ação recente - $e');
    }
  }

  Future<void> _confirmarMedicamentosBatch(
      List<Medicamento> medicamentos) async {
    if (medicamentos.isEmpty) {
      debugPrint('⚠️ Dashboard: Tentativa de confirmar lote vazio');
      return;
    }

    // Validar medicamentos antes de processar
    final validMedicamentos = medicamentos
        .where((m) =>
            m.id != null && m.id! > 0 && !(_statusMedicamentos[m.id] ?? false))
        .toList();

    if (validMedicamentos.isEmpty) {
      debugPrint('⚠️ Dashboard: Nenhum medicamento válido para confirmar');
      if (mounted) {
        FeedbackSnackbar.warning(
            context, 'Todos os medicamentos selecionados já foram confirmados');
      }
      setState(() => _isSelectionMode = false);
      return;
    }

    final timestamp = DateTime.now();
    final List<Medicamento> confirmedMedicamentos = [];
    final List<Medicamento> failedMedicamentos = [];

    try {
      for (final medicamento in validMedicamentos) {
        try {
          if (medicamento.id == null || medicamento.id! <= 0) {
            debugPrint(
                '⚠️ Dashboard: Medicamento com ID inválido: ${medicamento.nome}');
            failedMedicamentos.add(medicamento);
            continue;
          }

          // Atualizar UI otimisticamente
          setState(() {
            _statusMedicamentos[medicamento.id!] = true;
            _medicamentosTomados++;
            _medicamentosPendentes.removeWhere((m) => m.id == medicamento.id);
          });

          // Salvar no backend
          if (!_isOffline) {
            try {
              final medicamentoService = getIt<MedicamentoService>();
              await medicamentoService.toggleConcluido(
                medicamento.id!,
                true,
                timestamp,
              );

              // Cancelar notificações (não crítico se falhar)
              try {
                await NotificationService.confirmMedication(medicamento.id!);
              } catch (e) {
                debugPrint('⚠️ Dashboard: Erro ao cancelar notificações - $e');
                // Continuar mesmo se falhar
              }

              _addRecentAction(medicamento, timestamp, true);
              confirmedMedicamentos.add(medicamento);
            } catch (e) {
              debugPrint(
                  '❌ Dashboard: Erro ao confirmar ${medicamento.nome} - $e');
              // Reverter mudança de UI
              setState(() {
                _statusMedicamentos[medicamento.id!] = false;
                _medicamentosTomados--;
                if (!_medicamentosPendentes
                    .any((m) => m.id == medicamento.id)) {
                  _medicamentosPendentes.add(medicamento);
                }
              });
              failedMedicamentos.add(medicamento);
            }
          } else {
            // Modo offline
            try {
              await OfflineCacheService.addPendingAction({
                'type': 'toggle_medicamento',
                'medicamento_id': medicamento.id,
                'concluido': true,
                'data': timestamp.toIso8601String(),
              });
              confirmedMedicamentos.add(medicamento);
            } catch (e) {
              debugPrint('❌ Dashboard: Erro ao salvar ação offline - $e');
              // Reverter mudança de UI
              setState(() {
                _statusMedicamentos[medicamento.id!] = false;
                _medicamentosTomados--;
                if (!_medicamentosPendentes
                    .any((m) => m.id == medicamento.id)) {
                  _medicamentosPendentes.add(medicamento);
                }
              });
              failedMedicamentos.add(medicamento);
            }
          }
        } catch (e) {
          debugPrint(
              '❌ Dashboard: Erro inesperado ao processar ${medicamento.nome} - $e');
          failedMedicamentos.add(medicamento);
        }
      }

      // Atualizar estado final
      setState(() {
        _temAtraso = _medicamentosPendentes.isNotEmpty;
        _mensagemStatus = _temAtraso
            ? 'Você tem ${_medicamentosPendentes.length} medicamento(s) pendente(s).'
            : 'Você tomou tudo hoje.';
        _isSelectionMode = false;
      });

      // Mostrar feedback apropriado
      if (mounted) {
        if (failedMedicamentos.isNotEmpty && confirmedMedicamentos.isNotEmpty) {
          // Parcialmente sucesso
          FeedbackSnackbar.warning(
            context,
            '${confirmedMedicamentos.length} confirmado(s), ${failedMedicamentos.length} falhou(ram)',
          );
        } else if (failedMedicamentos.isNotEmpty) {
          // Todos falharam
          FeedbackSnackbar.error(
            context,
            'Erro ao confirmar medicamentos. Tente novamente.',
            onRetry: () => _confirmarMedicamentosBatch(validMedicamentos),
          );
          return;
        }

        if (confirmedMedicamentos.isNotEmpty) {
          UndoSnackbar.show(
            context,
            message:
                '${confirmedMedicamentos.length} medicamento(s) confirmado(s) com sucesso!',
            onUndo: () {
              try {
                // Desfazer todos os confirmados
                for (final med in confirmedMedicamentos) {
                  if (med.id != null && _statusMedicamentos[med.id] == true) {
                    _confirmarMedicamento(med);
                  }
                }
              } catch (e) {
                debugPrint('❌ Dashboard: Erro ao desfazer lote - $e');
                if (mounted) {
                  FeedbackSnackbar.error(context, 'Erro ao desfazer ações');
                }
              }
            },
            duration: const Duration(seconds: 15),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Dashboard: Erro crítico ao confirmar lote - $e');
      if (mounted) {
        FeedbackSnackbar.error(
          context,
          'Erro ao confirmar medicamentos em lote. Tente novamente.',
          onRetry: () => _confirmarMedicamentosBatch(validMedicamentos),
        );
      }
    }
  }

  /// Calcula o próximo medicamento baseado nos horários
  Medicamento? _calcularProximoMedicamento(
      List<Medicamento> medicamentos, Map<int, bool> statusMedicamentos) {
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
        final timeStr =
            '${_proximoHorario!.hour.toString().padLeft(2, '0')}:${_proximoHorario!.minute.toString().padLeft(2, '0')}';
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
                                      icon: Icon(Icons.volume_up,
                                          color: AppColors.textSecondary),
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
                      // ✅ Empty State Contextual: Se não há medicamentos, mostrar guia
                      if (_totalMedicamentos == 0 && _rotinas.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: _buildEmptyStateContextual(),
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            child: _buildSemaforoStatus()
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(
                                    begin: 0.1,
                                    end: 0,
                                    duration: 400.ms,
                                    curve: Curves.easeOut),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            child: _buildProximoMedicamento()
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 100.ms)
                                .slideY(
                                    begin: 0.1,
                                    end: 0,
                                    duration: 400.ms,
                                    delay: 100.ms,
                                    curve: Curves.easeOut),
                          ),
                        ),
                        if (_medicamentosPendentes.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              child: _buildMedicamentosPendentes()
                                  .animate()
                                  .fadeIn(duration: 400.ms, delay: 200.ms)
                                  .slideY(
                                      begin: 0.1,
                                      end: 0,
                                      duration: 400.ms,
                                      delay: 200.ms,
                                      curve: Curves.easeOut),
                            ),
                          ),
                        if (_recentActions.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              child: RecentActionsPanel(
                                actions: _recentActions,
                              )
                                  .animate()
                                  .fadeIn(duration: 400.ms, delay: 250.ms)
                                  .slideY(
                                      begin: 0.1,
                                      end: 0,
                                      duration: 400.ms,
                                      delay: 250.ms,
                                      curve: Curves.easeOut),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            child: _buildTimelineRotina()
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 300.ms)
                                .slideY(
                                    begin: 0.1,
                                    end: 0,
                                    duration: 400.ms,
                                    delay: 300.ms,
                                    curve: Curves.easeOut),
                          ),
                        ),
                      ],
                      SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.bottomNavBarPadding),
                      ),
                    ],
                  ),
                ),
              if (userId.isNotEmpty &&
                  !_isLoading &&
                  _errorMessage == null) ...[
                VoiceInterfaceWidget(
                  userId: userId,
                  showAsFloatingButton: true,
                ),
                Positioned(
                  bottom: 80,
                  right: 24,
                  child: QuickActionFAB(
                    onMedicationTap: () async {
                      // Navegar para tela de adicionar medicamento rápido
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddEditMedicamentoForm(),
                        ),
                      );
                      if (result == true && mounted) {
                        _loadUserData();
                      }
                    },
                    onVitalSignTap: () {
                      // Navegar para tela de registrar sinal vital
                      _showVitalSignDialog();
                    },
                    onEventTap: () {
                      // Navegar para tela de registrar evento
                      _showEventDialog();
                    },
                  ),
                ),
              ],
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
        borderColor: _temAtraso
            ? AppColors.error.withValues(alpha: 0.5)
            : AppColors.success.withValues(alpha: 0.4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (_temAtraso ? AppColors.error : AppColors.success)
                    .withValues(alpha: 0.12),
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
      hint:
          '${_proximoMedicamento!.nome}, às $horarioStr. Toque para ouvir detalhes.',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      _proximoMedicamento!.dosagem ??
                          'Dosagem não especificada',
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
    if (_medicamentosPendentes.isEmpty) {
      return const SizedBox.shrink();
    }

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
              Expanded(
                child: Text(
                  'Medicamentos Pendentes',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (!_isSelectionMode && _medicamentosPendentes.length > 1)
                IconButton(
                  onPressed: () => setState(() => _isSelectionMode = true),
                  icon: const Icon(Icons.checklist),
                  color: AppColors.primary,
                  tooltip: 'Seleção múltipla',
                ),
            ],
          ),
          const SizedBox(height: 16),
          BatchMedicationSelector(
            medications: _medicamentosPendentes,
            statusMedicamentos: _statusMedicamentos,
            loadingMedicamentos: _loadingMedicamentos,
            onConfirmSingle: _confirmarMedicamento,
            onConfirmBatch: _confirmarMedicamentosBatch,
            isSelectionMode: _isSelectionMode,
            onToggleSelectionMode: () =>
                setState(() => _isSelectionMode = false),
          ),
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
                    padding: EdgeInsets.only(
                        bottom: index < rotinasPendentes.length - 1 ? 12 : 0),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.6),
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

  /// ✅ Empty State Contextual para usuário sem medicamentos
  Widget _buildEmptyStateContextual() {
    final supabaseService = getIt<SupabaseService>();
    final user = supabaseService.currentUser;

    return FutureBuilder<bool>(
      future: user != null
          ? OnboardingService.hasFirstMedicamento(user.id)
          : Future.value(false),
      builder: (context, snapshot) {
        final hasFirstMedicamento = snapshot.data ?? false;

        // Se já cadastrou antes mas deletou tudo, mostrar mensagem diferente
        if (hasFirstMedicamento) {
          return CareMindEmptyState(
            icon: Icons.medication_liquid,
            title: 'Nenhum medicamento cadastrado',
            message:
                'Você não tem medicamentos cadastrados no momento.\nQue tal adicionar um novo?',
            actionLabel: 'Adicionar Medicamento',
            onAction: () {
              // Navegar para tela de medicamentos
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GestaoMedicamentosScreen(),
                ),
              );
            },
          );
        }

        // Primeiro acesso - mensagem mais guiada
        return CareMindEmptyState(
          icon: Icons.medication_liquid,
          title: 'Que tal cadastrar seu primeiro medicamento?',
          message:
              'Comece a cuidar da sua saúde cadastrando seus medicamentos e horários.',
          actionLabel: 'Adicionar Primeiro Medicamento',
          iconColor: AppColors.primary,
          onAction: () async {
            // Marcar que viu o empty state
            if (user != null) {
              await OnboardingService.markFirstMedicamento(user.id);
            }

            // Navegar para tela de medicamentos
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GestaoMedicamentosScreen(),
                ),
              );
            }
          },
        );
      },
    );
  }

  /// Mostra diálogo para registrar sinal vital
  void _showVitalSignDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Sinal Vital'),
        content: const Text(
          'A funcionalidade de registro de sinais vitais está em desenvolvimento. '
          'Em breve você poderá registrar pressão arterial, temperatura, glicemia e outros sinais vitais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Mostra diálogo para registrar evento
  Future<void> _showEventDialog() async {
    final descricaoController = TextEditingController();
    final tipoController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Evento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tipoController,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Evento',
                  hintText: 'Ex: Consulta, Exame, Sintoma',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Descreva o evento',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (tipoController.text.trim().isNotEmpty &&
                  descricaoController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final supabaseService = getIt<SupabaseService>();
        final user = supabaseService.currentUser;

        if (user != null) {
          final perfil = await supabaseService.getProfile(user.id);
          if (perfil != null) {
            await HistoricoEventosService.addEvento({
              'perfil_id': perfil.id,
              'tipo': tipoController.text.trim(),
              'descricao': descricaoController.text.trim(),
              'data': DateTime.now().toIso8601String(),
            });

            if (mounted) {
              FeedbackSnackbar.success(
                  context, 'Evento registrado com sucesso!');
              _loadUserData(); // Recarregar dados
            }
          }
        }
      } catch (e) {
        if (mounted) {
          FeedbackSnackbar.error(context, 'Erro ao registrar evento: $e');
        }
      }
    }

    descricaoController.dispose();
    tipoController.dispose();
  }
}
