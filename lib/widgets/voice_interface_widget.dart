import 'package:flutter/material.dart';
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
      
      // Vibração para feedback tátil
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 100);
      }

      await _voiceService.startListening(
        onResult: _handleVoiceResult,
        onError: _handleVoiceError,
      );
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
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 200);
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
    await _voiceService.speak(result.message);
    
    // Processar ações de navegação
    if (result.success && mounted) {
      await _handleNavigationAction(result.action);
    }
    
    setState(() {
      _isProcessing = false;
      _lastMessage = result.message;
    });

    // Feedback visual adicional baseado no resultado
    if (result.success) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 300);
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

    await _showError('Erro no reconhecimento de voz: $error');
  }

  Future<void> _handleNavigationAction(VoiceAction action) async {
    if (!mounted) return;

    switch (action) {
      case VoiceAction.navigateToMedications:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GestaoMedicamentosScreen()),
        );
        break;
        
      case VoiceAction.navigateToAppointments:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompromissosIdosoScreen()),
        );
        break;
        
      case VoiceAction.navigateToDashboard:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const IdosoDashboardScreen()),
          (_) => false,
        );
        break;
        
      case VoiceAction.navigateToSettings:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConfiguracoesScreen()),
        );
        break;
        
      case VoiceAction.emergencyCall:
        await _makeEmergencyCall();
        break;
        
      default:
        // Outras ações não requerem navegação
        break;
    }
  }

  Future<void> _makeEmergencyCall() async {
    try {
      final uri = Uri.parse('tel:192'); // SAMU - número de emergência
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await _voiceService.speak('Não foi possível fazer a chamada de emergência');
      }
    } catch (e) {
      await _voiceService.speak('Erro ao tentar chamar emergência');
    }
  }

  Future<void> _showError(String message) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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

    return Positioned(
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
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isListening ? _scaleAnimation.value : 1.0,
                child: FloatingActionButton(
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

