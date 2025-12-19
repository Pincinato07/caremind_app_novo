import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import '../services/voice_service.dart';
import '../services/medicamento_service.dart';
import '../services/rotina_service.dart';
import '../core/injection/injection.dart';
import '../screens/medication/gestao_medicamentos_screen.dart';
import '../screens/idoso/compromissos_screen.dart';
import '../screens/shared/configuracoes_screen.dart';
import '../screens/idoso/dashboard_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget de interface de voz (Voice-First)
/// Permite interação completa por comandos de voz
class VoiceInterfaceWidget extends StatefulWidget {
  final String userId;
  final bool showAsFloatingButton;
  final Color? buttonColor;
  final Color? listeningColor;

  const VoiceInterfaceWidget({
    super.key,
    required this.userId,
    this.showAsFloatingButton = true,
    this.buttonColor,
    this.listeningColor,
  });

  @override
  State<VoiceInterfaceWidget> createState() => _VoiceInterfaceWidgetState();
}

class _VoiceInterfaceWidgetState extends State<VoiceInterfaceWidget>
    with SingleTickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isAvailable = false;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _initializeVoice();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initializeVoice() async {
    final available = await _voiceService.initialize();
    if (mounted) {
      setState(() {
        _isAvailable = available;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (!_isAvailable) {
      await _showError('Serviço de voz não disponível. Verifique as permissões do microfone.');
      return;
    }

    if (_isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListening = false;
      });
      _animationController.stop();
      _animationController.reset();
    } else {
      setState(() {
        _isListening = true;
        _isProcessing = false;
        _lastMessage = null;
      });
      _animationController.repeat(reverse: true);
      
      try {
        // Vibração para feedback tátil
        try {
          final hasVibrator = await Vibration.hasVibrator();
          if (hasVibrator == true) {
            await Vibration.vibrate(duration: 100);
          }
        } catch (e) {
          // Ignorar erro de vibração - não é crítico
          debugPrint('Erro ao vibrar: $e');
        }

        // WCAG: Feedback sonoro ao iniciar escuta
        try {
          await _voiceService.speak("Estou ouvindo, fale agora");
        } catch (e) {
          // Ignorar erro de TTS - não é crítico, continuar com escuta
          debugPrint('Erro ao falar: $e');
        }

        await _voiceService.startListening(
          onResult: _handleVoiceResult,
          onError: _handleVoiceError,
        );
      } catch (e) {
        // Erro crítico ao iniciar escuta
        setState(() {
          _isListening = false;
        });
        _animationController.stop();
        _animationController.reset();
        await _showError('Erro ao iniciar reconhecimento de voz: $e');
      }
    }
  }

  Future<void> _handleVoiceResult(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isListening = false;
      _isProcessing = true;
    });
    
    _animationController.stop();
    _animationController.reset();

    // Vibração de confirmação
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      // Ignorar erro de vibração - não é crítico
      debugPrint('Erro ao vibrar: $e');
    }

    // Obter serviços
    final medicamentoService = getIt<MedicamentoService>();
    final rotinaService = getIt<RotinaService>();

    // Processar comando
    final result = await _voiceService.processCommand(
      text,
      widget.userId,
      medicamentoService: medicamentoService,
      rotinaService: rotinaService,
    );

    // Falar resposta
    try {
      await _voiceService.speak(result.message);
    } catch (e) {
      // Ignorar erro de TTS - não é crítico
      debugPrint('Erro ao falar resposta: $e');
    }
    
    // Processar ações de navegação
    try {
      if (result.success && mounted) {
        await _handleNavigationAction(result.action);
      } else if (!result.success && mounted) {
        // WCAG: Mostrar modal amigável quando comando não é reconhecido
        await _showErrorModal(result.message);
      }
    } catch (e) {
      debugPrint('Erro ao processar ação de navegação: $e');
      if (mounted) {
        await _showError('Erro ao processar comando: $e');
      }
    }
    
    setState(() {
      _isProcessing = false;
      _lastMessage = result.message;
    });

    // Feedback visual adicional baseado no resultado
    if (result.success) {
      try {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          await Vibration.vibrate(duration: 300);
        }
      } catch (e) {
        // Ignorar erro de vibração - não é crítico
        debugPrint('Erro ao vibrar: $e');
      }
    }
  }

  Future<void> _handleVoiceError(String error) async {
    setState(() {
      _isListening = false;
      _isProcessing = false;
    });
    
    _animationController.stop();
    _animationController.reset();

    // WCAG: Mostrar modal amigável para erro de microfone
    await _showMicrophoneErrorModal(error);
  }

  Future<void> _handleNavigationAction(VoiceAction action) async {
    if (!mounted) return;

    try {
      switch (action) {
        case VoiceAction.navigateToMedications:
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GestaoMedicamentosScreen()),
            );
          }
          break;
          
        case VoiceAction.navigateToAppointments:
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompromissosIdosoScreen()),
            );
          }
          break;
          
        case VoiceAction.navigateToDashboard:
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const IdosoDashboardScreen()),
              (_) => false,
            );
          }
          break;
          
        case VoiceAction.navigateToSettings:
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfiguracoesScreen()),
            );
          }
          break;
          
        case VoiceAction.emergencyCall:
          await _makeEmergencyCall();
          break;
          
        default:
          // Outras ações não requerem navegação
          break;
      }
    } catch (e) {
      debugPrint('Erro ao navegar: $e');
      if (mounted) {
        await _showError('Erro ao navegar. Tente novamente.');
      }
    }
  }

  Future<void> _makeEmergencyCall() async {
    try {
      final uri = Uri.parse('tel:192'); // SAMU - número de emergência
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        try {
          await _voiceService.speak('Não foi possível fazer a chamada de emergência');
        } catch (ttsError) {
          debugPrint('Erro ao falar mensagem de emergência: $ttsError');
        }
        if (mounted) {
          await _showError('Não foi possível fazer a chamada de emergência');
        }
      }
    } catch (e) {
      debugPrint('Erro ao fazer chamada de emergência: $e');
      try {
        await _voiceService.speak('Erro ao tentar chamar emergência');
      } catch (ttsError) {
        debugPrint('Erro ao falar mensagem de erro: $ttsError');
      }
      if (mounted) {
        await _showError('Erro ao tentar chamar emergência. Tente ligar manualmente.');
      }
    }
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } catch (e) {
      // Fallback: apenas logar o erro se não conseguir mostrar SnackBar
      debugPrint('Erro ao mostrar mensagem de erro: $e');
      debugPrint('Mensagem original: $message');
    }
  }

  /// WCAG: Modal amigável quando comando de voz não é reconhecido
  Future<void> _showErrorModal(String message) async {
    if (!mounted) return;

    // Vibração de erro
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(pattern: [0, 200, 100, 200]);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, size: 40, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Não consegui entender',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tente falar mais devagar ou use um destes comandos:',
                style: TextStyle(fontSize: 18, height: 1.5),
              ),
              const SizedBox(height: 20),
              // Botões grandes com comandos sugeridos
              _buildCommandSuggestionButton(
                context,
                'Confirmar Remédio',
                Icons.medication_liquid,
                () {
                  Navigator.pop(context);
                  _navigateToMedications();
                },
              ),
              const SizedBox(height: 12),
              _buildCommandSuggestionButton(
                context,
                'Listar Remédios',
                Icons.list,
                () {
                  Navigator.pop(context);
                  _navigateToMedications();
                },
              ),
              const SizedBox(height: 12),
              _buildCommandSuggestionButton(
                context,
                'Ver Compromissos',
                Icons.calendar_today,
                () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CompromissosIdosoScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              Divider(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56, // WCAG: Altura mínima de 48px
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navegar para tela de medicamentos manualmente
                    _navigateToMedications();
                  },
                  icon: Icon(Icons.touch_app, size: 24),
                  label: Text(
                    'Usar app manualmente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tentar novamente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// WCAG: Modal amigável quando microfone falha
  Future<void> _showMicrophoneErrorModal(String error) async {
    if (!mounted) return;

    // Vibração de erro
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(pattern: [0, 200, 100, 200]);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mic_off, size: 40, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Microfone não disponível',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Não foi possível usar o microfone. Você pode:',
                style: TextStyle(fontSize: 18, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56, // WCAG: Altura mínima de 48px
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Abrir configurações do app
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ConfiguracoesScreen()),
                    );
                  },
                  icon: Icon(Icons.settings, size: 28),
                  label: Text(
                    'Verificar permissões',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56, // WCAG: Altura mínima de 48px
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navegar para tela de medicamentos
                    _navigateToMedications();
                  },
                  icon: Icon(Icons.medication_liquid, size: 28),
                  label: Text(
                    'Usar app manualmente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Fechar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandSuggestionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 56, // WCAG: Altura mínima de 48px
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  void _navigateToMedications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GestaoMedicamentosScreen()),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAvailable && !_isListening) {
      return const SizedBox.shrink();
    }

    if (widget.showAsFloatingButton) {
      return _buildFloatingButton();
    } else {
      return _buildInlineButton();
    }
  }

  Widget _buildFloatingButton() {
    final buttonColor = widget.buttonColor ?? Theme.of(context).primaryColor;
    final listeningColor = widget.listeningColor ?? Colors.red;

    return Stack(
      children: [
        // WCAG: Overlay visual proeminente quando está ouvindo
        if (_isListening)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícone grande pulsante
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Texto grande "OUVINDO..."
                    Text(
                      'OUVINDO...',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                            color: Colors.black.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fale agora',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // FAB no canto
        Positioned(
          bottom: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lastMessage != null && !_isListening && !_isProcessing)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  constraints: const BoxConstraints(maxWidth: 250),
                  child: Text(
                    _lastMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              // WCAG: Aumentar FAB para 64dp (melhor para idosos)
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _scaleAnimation.value : 1.0,
                    child: FloatingActionButton.large(
                      onPressed: _isProcessing ? null : _toggleListening,
                      backgroundColor: _isListening 
                          ? listeningColor 
                          : (_isProcessing ? Colors.grey : buttonColor),
                      child: _buildIcon(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineButton() {
    final buttonColor = widget.buttonColor ?? Theme.of(context).primaryColor;
    final listeningColor = widget.listeningColor ?? Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          if (_lastMessage != null && !_isListening && !_isProcessing)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _lastMessage!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isListening ? _scaleAnimation.value : 1.0,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _toggleListening,
                  icon: _buildIcon(),
                  label: Text(_isListening 
                      ? 'Ouvindo...' 
                      : (_isProcessing ? 'Processando...' : 'Falar')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening 
                        ? listeningColor 
                        : (_isProcessing ? Colors.grey : buttonColor),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    if (_isProcessing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    
    return Icon(
      _isListening ? Icons.mic : Icons.mic_none,
      color: Colors.white,
    );
  }
}

/// Widget wrapper para adicionar interface de voz a qualquer tela
class VoiceInterfaceWrapper extends StatelessWidget {
  final Widget child;
  final String userId;
  final bool showVoiceButton;

  const VoiceInterfaceWrapper({
    super.key,
    required this.child,
    required this.userId,
    this.showVoiceButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showVoiceButton)
          VoiceInterfaceWidget(
            userId: userId,
            showAsFloatingButton: true,
          ),
      ],
    );
  }
}

