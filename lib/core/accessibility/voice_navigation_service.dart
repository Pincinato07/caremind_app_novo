import 'package:flutter/material.dart';
import '../../services/accessibility_service.dart';
import '../../services/voice_service.dart';
import '../../screens/idoso/dashboard_screen.dart';
import '../../screens/medication/gestao_medicamentos_screen.dart';
import '../../screens/idoso/compromissos_screen.dart';
import '../../screens/shared/configuracoes_screen.dart';
import '../../screens/shared/perfil_screen.dart';
import '../../screens/idoso/ajuda_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Serviço especializado em navegação por voz
/// Fornece navegação completa entre telas usando comandos de voz
class VoiceNavigationService {
  static final VoiceNavigationService _instance = VoiceNavigationService._internal();
  factory VoiceNavigationService() => _instance;
  VoiceNavigationService._internal();

  final VoiceService _voiceService = VoiceService();

  /// Navega para uma tela específica com feedback TTS
  Future<void> navigateToScreen(
    BuildContext context,
    VoiceScreen screen, {
    String? customMessage,
  }) async {
    if (!context.mounted) return;

    final screenName = _getScreenName(screen);
    final message = customMessage ?? 'Abrindo $screenName...';
    
    // Feedback TTS antes da navegação
    await _voiceService.speak(message);
    
    // Vibração de confirmação
    await AccessibilityService.vibrar(duration: 200);

    // Executar navegação
    switch (screen) {
      case VoiceScreen.dashboard:
        await _navigateToDashboard(context);
        break;
      case VoiceScreen.medications:
        await _navigateToMedications(context);
        break;
      case VoiceScreen.appointments:
        await _navigateToAppointments(context);
        break;
      case VoiceScreen.settings:
        await _navigateToSettings(context);
        break;
      case VoiceScreen.profile:
        await _navigateToProfile(context);
        break;
      case VoiceScreen.help:
        await _navigateToHelp(context);
        break;
      case VoiceScreen.emergency:
        await _makeEmergencyCall(context);
        break;
    }
  }

  Future<void> _navigateToDashboard(BuildContext context) async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const IdosoDashboardScreen()),
      (_) => false,
    );
    await _voiceService.speak('Menu principal. Aqui você pode ver seus medicamentos, compromissos e usar o assistente de voz.');
  }

  Future<void> _navigateToMedications(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GestaoMedicamentosScreen()),
    );
    await _voiceService.speak('Tela de medicamentos. Você pode ver, adicionar e confirmar seus remédios.');
  }

  Future<void> _navigateToAppointments(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompromissosIdosoScreen()),
    );
    await _voiceService.speak('Tela de compromissos. Aqui estão seus próximos compromissos agendados.');
  }

  Future<void> _navigateToSettings(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracoesScreen()),
    );
    await _voiceService.speak('Configurações. Aqui você pode ajustar o assistente de voz, notificações e outras preferências.');
  }

  Future<void> _navigateToProfile(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PerfilScreen()),
    );
    await _voiceService.speak('Seu perfil. Aqui você pode ver e editar suas informações pessoais.');
  }

  Future<void> _navigateToHelp(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AjudaScreen()),
    );
    await _voiceService.speak('Tela de ajuda. Aqui você encontra informações sobre como usar o aplicativo.');
  }

  Future<void> _makeEmergencyCall(BuildContext context) async {
    await _voiceService.speak('Chamando emergência...');
    
    try {
      final uri = Uri.parse('tel:192'); // SAMU
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await _voiceService.speak('Não foi possível fazer a chamada. Verifique se seu dispositivo permite chamadas.');
      }
    } catch (e) {
      await _voiceService.speak('Erro ao tentar chamar emergência. Tente novamente.');
    }
  }

  /// Anuncia o conteúdo da tela atual
  Future<void> announceScreenContent(BuildContext context, String screenName) async {
    final message = _getScreenWelcomeMessage(screenName);
    await _voiceService.speak(message);
  }

  /// Fornece ajuda contextual baseada na tela atual
  Future<void> provideContextualHelp(BuildContext context, String screenName) async {
    final helpMessage = _getContextualHelp(screenName);
    await _voiceService.speak(helpMessage);
  }

  /// Processa comandos de navegação avançados
  Future<bool> processNavigationCommand(
    BuildContext context,
    String command,
  ) async {
    final lowerCommand = command.toLowerCase().trim();

    // Comandos de voltar
    if (_matchesCommand(lowerCommand, [
      'voltar',
      'voltar para trás',
      'tela anterior',
      'sair',
    ])) {
      if (Navigator.canPop(context)) {
        await _voiceService.speak('Voltando para a tela anterior...');
        Navigator.pop(context);
        return true;
      } else {
        await _voiceService.speak('Você já está na tela inicial.');
        return false;
      }
    }

    // Comandos de emergência
    if (_matchesCommand(lowerCommand, [
      'emergência',
      'socorro',
      'ajuda urgente',
      'ligar para emergência',
      'samu',
    ])) {
      await navigateToScreen(context, VoiceScreen.emergency);
      return true;
    }

    return false;
  }

  bool _matchesCommand(String command, List<String> patterns) {
    return patterns.any((pattern) => 
      command.contains(pattern) || 
      pattern.split(' ').every((word) => command.contains(word))
    );
  }

  String _getScreenName(VoiceScreen screen) {
    switch (screen) {
      case VoiceScreen.dashboard:
        return 'menu principal';
      case VoiceScreen.medications:
        return 'medicamentos';
      case VoiceScreen.appointments:
        return 'compromissos';
      case VoiceScreen.settings:
        return 'configurações';
      case VoiceScreen.profile:
        return 'perfil';
      case VoiceScreen.help:
        return 'ajuda';
      case VoiceScreen.emergency:
        return 'emergência';
    }
  }

  String _getScreenWelcomeMessage(String screenName) {
    switch (screenName.toLowerCase()) {
      case 'dashboard':
      case 'menu principal':
        return 'Bem-vindo ao menu principal. Aqui você pode ver seus medicamentos, compromissos e usar o assistente de voz.';
      case 'medicamentos':
        return 'Tela de medicamentos. Toque em um medicamento para ouvir os detalhes ou use comandos de voz para confirmar.';
      case 'compromissos':
        return 'Tela de compromissos. Aqui estão seus próximos agendamentos.';
      case 'configurações':
        return 'Tela de configurações. Aqui você pode ajustar as preferências do aplicativo.';
      case 'perfil':
        return 'Seu perfil. Aqui você pode ver e editar suas informações.';
      case 'ajuda':
        return 'Tela de ajuda. Encontre informações sobre como usar o aplicativo.';
      default:
        return 'Tela $screenName carregada.';
    }
  }

  String _getContextualHelp(String screenName) {
    switch (screenName.toLowerCase()) {
      case 'dashboard':
      case 'menu principal':
        return 'Para navegar, diga "ir para" seguido do nome da tela. Você também pode usar o assistente de voz dizendo "falar com CareMind".';
      case 'medicamentos':
        return 'Diga "confirmei o remédio" para marcar como tomado, ou "quais remédios" para listar todos.';
      case 'compromissos':
        return 'Toque em um compromisso para ouvir os detalhes. Use comandos de voz para navegar.';
      case 'configurações':
        return 'Use os botões para ajustar as preferências. Diga "voltar" para sair.';
      default:
        return 'Use comandos de voz ou toque nos elementos para interagir. Diga "ajuda" para mais informações.';
    }
  }
}

/// Enumeração de telas para navegação por voz
enum VoiceScreen {
  dashboard,
  medications,
  appointments,
  settings,
  profile,
  help,
  emergency,
}
