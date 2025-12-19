import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import 'package:vibration/vibration.dart';
import '../../services/supabase_service.dart';
import '../../services/emergencia_service.dart';
import '../../services/accessibility_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/errors/error_handler.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';

/// Tela de Ajuda/Emergência para o perfil IDOSO
class AjudaScreen extends StatefulWidget {
  const AjudaScreen({super.key});

  @override
  State<AjudaScreen> createState() => _AjudaScreenState();
}

class _AjudaScreenState extends State<AjudaScreen> {
  String? _telefoneCuidador;
  String? _nomeCuidador;
  bool _isLoading = true;
  bool _isDisparandoEmergencia = false;
  bool _isHoldingButton = false;
  int _holdCountdown = 3;
  Timer? _holdTimer;
  final EmergenciaService _emergenciaService = EmergenciaService();

  @override
  void initState() {
    super.initState();
    _carregarTelefoneCuidador();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregarTelefoneCuidador() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user != null) {
        final cuidador = await supabaseService.getCuidadorPrincipal(user.id);

        if (mounted) {
          setState(() {
            _telefoneCuidador = cuidador?['telefone'] as String?;
            _nomeCuidador = cuidador?['nome'] as String?;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Inicia o processo de hold para acionar emergência
  void _iniciarHold() {
    if (_isDisparandoEmergencia) return;

    setState(() {
      _isHoldingButton = true;
      _holdCountdown = 3;
    });

    // Vibração inicial
    Vibration.vibrate(duration: 100);

    // Timer para contagem regressiva
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _holdCountdown--;
      });

      // Vibração a cada segundo
      Vibration.vibrate(duration: 100);

      if (_holdCountdown <= 0) {
        timer.cancel();
        _finalizarHold();
      }
    });
  }

  /// Cancela o hold
  void _cancelarHold() {
    _holdTimer?.cancel();
    if (mounted) {
      setState(() {
        _isHoldingButton = false;
        _holdCountdown = 3;
      });
    }
  }

  /// Finaliza o hold e aciona a emergência
  void _finalizarHold() {
    _holdTimer?.cancel();
    if (mounted) {
      setState(() {
        _isHoldingButton = false;
        _holdCountdown = 3;
      });
    }
    _acionarPanico();
  }

  /// Aciona botão de pânico - dispara alerta para TODOS os familiares
  /// Envia SMS, notificações push e registra no histórico
  Future<void> _acionarPanico() async {
    if (_isDisparandoEmergencia) return;

    // Confirmação antes de acionar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          '🚨 Confirmar Emergência',
          style: AppTextStyles.leagueSpartan(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.red,
          ),
        ),
        content: Text(
          'Isso enviará alertas de emergência para TODOS os seus familiares via SMS e notificações. Deseja continuar?',
          style: AppTextStyles.leagueSpartan(
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.leagueSpartan(
                fontWeight: FontWeight.w700,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'SIM, ACIONAR',
              style: AppTextStyles.leagueSpartan(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isDisparandoEmergencia = true);

    // Vibração forte para feedback tátil
    if (await Vibration.hasVibrator() == true) {
      await Vibration.vibrate(duration: 1000);
    }

    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user == null) {
        throw UnknownException(message: 'Usuário não autenticado');
      }

      // Acionar emergência via Edge Function (GPS será capturado automaticamente)
      final resultado = await _emergenciaService.acionarPanico(
        idosoId: user.id,
        capturarGPS: true, // Captura GPS automaticamente
      );

      // Feedback de sucesso
      await AccessibilityService.speak(
        'Alerta de emergência enviado para ${resultado['familiares_notificados']} familiar(es).',
      );

      if (mounted) {
        FeedbackService.showSuccess(
          context,
          '🚨 Alerta enviado para ${resultado['familiares_notificados']} familiar(es)!',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      // Determinar mensagem de erro amigável
      String errorMessage;
      bool isNetworkError = false;
      bool canRetry = false;

      if (e is AppException) {
        errorMessage = e.message;
        // Verificar se é erro de rede
        if (e.message.contains('conexão') ||
            e.message.contains('internet') ||
            e.message.contains('Tempo esgotado')) {
          isNetworkError = true;
          canRetry = true;
        }
      } else {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('socket') ||
            errorStr.contains('network') ||
            errorStr.contains('connection') ||
            errorStr.contains('timeout')) {
          errorMessage =
              'Sem conexão com a internet. Verifique sua conexão e tente novamente.';
          isNetworkError = true;
          canRetry = true;
        } else {
          errorMessage =
              'Erro ao acionar emergência. Tente ligar diretamente para seu familiar.';
        }
      }

      // Feedback de voz
      await AccessibilityService.speak(
        isNetworkError
            ? 'Erro de conexão. Tente novamente ou ligue diretamente.'
            : 'Erro ao acionar emergência. Tente ligar diretamente.',
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              isNetworkError
                  ? '⚠️ Erro de Conexão'
                  : '❌ Erro ao Acionar Emergência',
              style: AppTextStyles.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isNetworkError ? Colors.orange : Colors.red,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage,
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                if (isNetworkError) ...[
                  const SizedBox(height: 16),
                  Text(
                    '💡 Dica: O alerta pode ter sido enviado mesmo com erro. Verifique se seus familiares receberam a notificação.',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (canRetry)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _acionarPanico(); // Tentar novamente
                  },
                  child: Text(
                    'TENTAR NOVAMENTE',
                    style: AppTextStyles.leagueSpartan(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTextStyles.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                  ),
                ),
              ),
              if (_telefoneCuidador != null && _telefoneCuidador!.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _ligarParaFamiliar();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'LIGAR DIRETO',
                    style: AppTextStyles.leagueSpartan(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDisparandoEmergencia = false);
      }
    }
  }

  Future<void> _ligarParaFamiliar() async {
    if (_telefoneCuidador == null || _telefoneCuidador!.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Número não disponível',
              style: AppTextStyles.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Nenhum número de emergência cadastrado. Peça para seu familiar configurar o telefone no aplicativo.',
              style: AppTextStyles.leagueSpartan(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTextStyles.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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
    final telefoneLimpo = _telefoneCuidador!.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$telefoneLimpo');

    try {
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
                style: AppTextStyles.leagueSpartan(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                'Este dispositivo não possui capacidade de fazer chamadas telefônicas.',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: AppTextStyles.leagueSpartan(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
        final errorMessage =
            e is AppException ? e.message : 'Erro ao iniciar chamada: $e';

        FeedbackService.showError(
          context,
          ErrorHandler.toAppException(Exception(errorMessage)),
        );
      }
    }
  }

  Future<void> _abrirWhatsApp() async {
    if (_telefoneCuidador == null || _telefoneCuidador!.isEmpty) {
      if (mounted) {
        FeedbackService.showWarning(
          context,
          'Número de telefone não disponível para WhatsApp',
        );
      }
      return;
    }

    // Formatar telefone (remover caracteres não numéricos, exceto +)
    final telefoneLimpo = _telefoneCuidador!.replaceAll(RegExp(r'[^\d+]'), '');
    // Remover + se houver e adicionar código do país se não tiver
    final telefoneFormatado = telefoneLimpo.startsWith('+')
        ? telefoneLimpo.substring(1)
        : telefoneLimpo.startsWith('55')
            ? telefoneLimpo
            : '55$telefoneLimpo';

    // Mensagem pré-formatada
    final mensagem = Uri.encodeComponent(
      '🚨 EMERGÊNCIA - Preciso de ajuda imediata!',
    );

    final uri = Uri.parse('https://wa.me/$telefoneFormatado?text=$mensagem');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          FeedbackService.showWarning(
            context,
            'WhatsApp não está instalado ou não está disponível',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        FeedbackService.showError(context, ErrorHandler.toAppException(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      '🚨 Emergência',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Precisa de ajuda imediata?',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // BOTÃO DE PÂNICO GIGANTE (Principal)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: AnimatedCard(
                  index: 0,
                  child: CareMindCard(
                    variant: CardVariant.glass,
                    padding: AppSpacing.paddingXLarge,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 80,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'BOTÃO DE PÂNICO',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Envia alerta para TODOS os familiares via SMS e notificações',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Botão com delay de cancelamento (hold 3 segundos)
                        GestureDetector(
                          onLongPressStart: (_) => _iniciarHold(),
                          onLongPressEnd: (_) => _cancelarHold(),
                          child: SizedBox(
                            width: double.infinity,
                            height: 100, // Botão GIGANTE para acessibilidade
                            child: ElevatedButton(
                              onPressed: _isDisparandoEmergencia
                                  ? null
                                  : () {
                                      // Clique simples também funciona (para acessibilidade)
                                      _acionarPanico();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 8,
                                shadowColor: Colors.red.withValues(alpha: 0.5),
                              ),
                              child: _isDisparandoEmergencia
                                  ? const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 4,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : _isHoldingButton
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '$_holdCountdown',
                                              style:
                                                  AppTextStyles.leagueSpartan(
                                                fontSize: 48,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Segure para confirmar',
                                              style:
                                                  AppTextStyles.leagueSpartan(
                                                fontSize: 14,
                                                color: Colors.white
                                                    .withValues(alpha: 0.9),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.warning, size: 36),
                                            const SizedBox(width: 12),
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'ACIONAR EMERGÊNCIA',
                                                  style: AppTextStyles
                                                      .leagueSpartan(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Botão de ligação direta e WhatsApp
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
                child: AnimatedCard(
                  index: 1,
                  child: CareMindCard(
                    variant: CardVariant.glass,
                    padding: AppSpacing.paddingLarge,
                    child: Column(
                      children: [
                        Text(
                          'Ou ligue diretamente',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Botão de ligação
                        SizedBox(
                          width: double.infinity,
                          height: 70,
                          child: ElevatedButton.icon(
                            onPressed: _ligarParaFamiliar,
                            icon: const Icon(Icons.phone, size: 28),
                            label: Text(
                              'LIGAR PARA FAMILIAR',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                        if (_telefoneCuidador != null &&
                            _telefoneCuidador!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          // Botão WhatsApp
                          SizedBox(
                            width: double.infinity,
                            height: 70,
                            child: ElevatedButton.icon(
                              onPressed: _abrirWhatsApp,
                              icon: const Icon(Icons.chat, size: 28),
                              label: Text(
                                'ABRIR WHATSAPP',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF25D366), // Cor do WhatsApp
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Informações de contato
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
                child: AnimatedCard(
                  index: 2,
                  child: CareMindCard(
                    variant: CardVariant.glass,
                    padding: AppSpacing.paddingLarge,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informações de Contato',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        else if (_nomeCuidador != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Familiar: $_nomeCuidador',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              if (_telefoneCuidador != null &&
                                  _telefoneCuidador!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Telefone: $_telefoneCuidador',
                                    style: AppTextStyles.leagueSpartan(
                                      fontSize: 16,
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '⚠️ Telefone não cadastrado',
                                    style: AppTextStyles.leagueSpartan(
                                      fontSize: 16,
                                      color: Colors.orange.shade300,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else
                          Text(
                            'Nenhum familiar vinculado encontrado.',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          '💡 Dica: O botão de pânico envia alertas para TODOS os seus familiares cadastrados, mesmo que você não tenha o telefone deles.',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.bottomNavBarPadding)),
          ],
        ),
      ),
    );
  }
}
