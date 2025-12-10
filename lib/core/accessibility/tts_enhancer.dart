import 'package:flutter/material.dart';
import '../../services/accessibility_service.dart';
import '../../services/settings_service.dart';
import '../../core/injection/injection.dart';

/// Serviço de melhoria de TTS para todo o aplicativo
/// Fornece feedback de voz contextual e semântica completa
class TTSEnhancer {
  static final TTSEnhancer _instance = TTSEnhancer._internal();
  factory TTSEnhancer() => _instance;
  TTSEnhancer._internal();

  /// Anuncia mudanças de tela com contexto completo
  static Future<void> announceScreenChange(
    BuildContext context,
    String screenName, {
    String? userName,
    Map<String, dynamic>? additionalData,
    bool force = false, // Ignora configuração de auto-read se true
  }) async {
    // Verificar se leitura automática está habilitada (a menos que seja forçado)
    if (!force) {
      try {
        final settingsService = getIt<SettingsService>();
        if (!settingsService.accessibilityAutoRead) {
          return; // Leitura automática desabilitada
        }
      } catch (e) {
        // Se não conseguir obter o SettingsService, assume que está habilitado
      }
    }
    
    final message = _buildScreenWelcomeMessage(screenName, userName, additionalData);
    await AccessibilityService.speak(message);
  }

  /// Fornece feedback TTS para ações do usuário
  static Future<void> provideActionFeedback(
    String action,
    {String? target, 
    bool success = true}) async {
    String message;
    
    if (success) {
      message = target != null 
          ? '$action $target concluída com sucesso.'
          : '$action concluída com sucesso.';
    } else {
      message = target != null 
          ? 'Erro ao $action $target. Tente novamente.'
          : 'Erro ao $action. Tente novamente.';
    }
    
    await AccessibilityService.speak(message);
    await AccessibilityService.vibrar(duration: success ? 200 : 500);
  }

  /// Anuncia uma ação específica (compatibilidade)
  static Future<void> announceAction(String action) async {
    await AccessibilityService.speak(action);
  }

  /// Anuncia sucesso (compatibilidade)
  static Future<void> announceSuccess(String message) async {
    await AccessibilityService.speak(message);
  }

  /// Anuncia erro (compatibilidade)
  static Future<void> announceError(String error) async {
    await AccessibilityService.speak(error);
  }

  /// Anuncia mudança em formulário (compatibilidade)
  static Future<void> announceFormChange(String field) async {
    await AccessibilityService.speak('Campo $field alterado');
  }

  /// Anuncia validação de formulário (compatibilidade)
  static Future<void> announceValidationError(String error) async {
    await AccessibilityService.speak('Erro de validação: $error');
  }

  /// Descreve elementos interativos para leitores de tela
  static String describeElement({
    required String type,
    required String label,
    String? hint,
    String? value,
    bool isEnabled = true,
  }) {
    final parts = <String>[label];
    
    if (type.isNotEmpty) {
      parts.add(type);
    }
    
    if (hint != null && hint.isNotEmpty) {
      parts.add(hint);
    }
    
    if (value != null && value.isNotEmpty) {
      parts.add('Valor: $value');
    }
    
    if (!isEnabled) {
      parts.add('Desativado');
    }
    
    return parts.join(', ');
  }

  /// Anuncia navegação entre telas
  static Future<void> announceNavigation(
    String fromScreen,
    String toScreen, {
    String? userName,
  }) async {
    final message = userName != null 
        ? 'Navegando de $fromScreen para $toScreen, $userName.'
        : 'Navegando de $fromScreen para $toScreen.';
    
    await AccessibilityService.speak(message);
  }

  /// Fornece ajuda contextual baseada na tela atual
  static Future<void> provideContextualHelp(String screenName) async {
    final helpMessage = _getContextualHelp(screenName);
    await AccessibilityService.speak(helpMessage);
  }

  /// Anuncia estado do formulário
  static Future<void> announceFormState({
    required int totalFields,
    required int completedFields,
    String? formName,
  }) async {
    final percentage = totalFields > 0 
        ? ((completedFields / totalFields) * 100).round()
        : 0;
    
    final message = formName != null
        ? 'Formulário $formName: $completedFields de $totalFields campos preenchidos, $percentage% completo.'
        : '$completedFields de $totalFields campos preenchidos, $percentage% completo.';
    
    await AccessibilityService.speak(message);
  }

  /// Anuncia mudanças em listas ou grids
  static Future<void> announceListChange({
    required String listName,
    required int itemCount,
    String? action,
  }) async {
    String message;
    
    if (action != null) {
      message = '$listName: $action. Total de $itemCount itens.';
    } else {
      message = '$listName com $itemCount itens.';
    }
    
    await AccessibilityService.speak(message);
  }

  /// Anuncia sucesso em operações críticas
  static Future<void> announceCriticalSuccess(String operation) async {
    await AccessibilityService.speak('$operation realizada com sucesso!');
    await AccessibilityService.vibrar(duration: 300);
  }

  /// Anuncia erro em operações críticas
  static Future<void> announceCriticalError(String error) async {
    await AccessibilityService.speak('Erro: $error');
    await AccessibilityService.vibrar(duration: 500);
  }

  /// Lê conteúdo de listas e cards
  static Future<void> announceContent({
    required String type,
    required List<String> items,
    String? title,
  }) async {
    final buffer = StringBuffer();
    
    if (title != null) {
      buffer.write('$title. ');
    }
    
    if (items.isEmpty) {
      buffer.write('Nenhum $type encontrado.');
    } else {
      buffer.write('${items.length} ${items.length == 1 ? type.substring(0, type.length - 1) : type} encontrados: ');
      for (int i = 0; i < items.length; i++) {
        if (i > 0) buffer.write(', ');
        buffer.write('${i + 1}: ${items[i]}');
      }
    }
    
    await AccessibilityService.speak(buffer.toString());
  }

  /// Lê detalhes de um item específico
  static Future<void> announceItemDetails({
    required String itemType,
    required String name,
    Map<String, String>? details,
  }) async {
    final buffer = StringBuffer();
    buffer.write('$itemType: $name');
    
    if (details != null && details.isNotEmpty) {
      details.forEach((key, value) {
        buffer.write('. $key: $value');
      });
    }
    
    await AccessibilityService.speak(buffer.toString());
  }

  /// Constrói mensagem de boas-vindas para telas
  static String _buildScreenWelcomeMessage(
    String screenName, 
    String? userName,
    Map<String, dynamic>? additionalData,
  ) {
    final greeting = userName != null ? 'Olá, $userName.' : '';
    
    switch (screenName.toLowerCase()) {
      case 'dashboard':
      case 'menu principal':
        return '$greeting Bem-vindo ao menu principal. Aqui você pode ver seus medicamentos, compromissos e usar o assistente de voz.';
        
      case 'medicamentos':
        return '$greeting Tela de medicamentos. Você pode ver, adicionar e confirmar seus remédios.';
        
      case 'compromissos':
        return '$greeting Tela de compromissos. Aqui estão seus próximos agendamentos.';
        
      case 'configurações':
        return '$greeting Tela de configurações. Aqui você pode ajustar as preferências do aplicativo.';
        
      case 'perfil':
        return '$greeting Seu perfil. Aqui você pode ver e editar suas informações pessoais.';
        
      case 'relatórios':
        return '$greeting Tela de relatórios. Aqui você pode ver seu histórico e estatísticas.';
        
      case 'ajuda':
        return '$greeting Tela de ajuda. Encontre informações sobre como usar o aplicativo.';
        
      default:
        return '$greeting Tela $screenName carregada.';
    }
  }

  /// Obtém ajuda contextual para telas específicas
  static String _getContextualHelp(String screenName) {
    switch (screenName.toLowerCase()) {
      case 'dashboard':
      case 'menu principal':
        return 'Para navegar, diga "ir para" seguido do nome da tela. Você também pode usar o assistente de voz dizendo "falar com CareMind". Toque nos cards para ouvir detalhes.';
        
      case 'medicamentos':
        return 'Diga "confirmei o remédio" para marcar como tomado, "quais remédios" para listar todos, ou toque em um medicamento para ouvir os detalhes.';
        
      case 'compromissos':
        return 'Toque em um compromisso para ouvir os detalhes. Use comandos de voz para navegar ou dizer "ajuda" para mais opções.';
        
      case 'configurações':
        return 'Use os botões para ajustar as preferências. Diga "voltar" para sair ou use o assistente de voz para navegação.';
        
      case 'perfil':
        return 'Toque nos campos para editar suas informações. Diga "salvar" para confirmar as alterações.';
        
      default:
        return 'Use comandos de voz ou toque nos elementos para interagir. Diga "ajuda" para ver todos os comandos disponíveis.';
    }
  }

  /// Anuncia mudanças em switches e toggles
  static Future<void> announceToggleChange(
    String toggleName,
    bool newValue,
  ) async {
    final status = newValue ? 'ativado' : 'desativado';
    await AccessibilityService.speak('$toggleName $status');
  }

  /// Anuncia progresso de operações longas
  static Future<void> announceProgress(
    String operation,
    int current,
    int total,
  ) async {
    final percentage = total > 0 ? ((current / total) * 100).round() : 0;
    await AccessibilityService.speak('$operation: $percentage% completo');
  }

  /// Anuncia alterações em dados importantes
  static Future<void> announceDataChange(
    String dataType,
    String changeType,
    String? itemName,
  ) async {
    final item = itemName != null ? ' $itemName' : '';
    await AccessibilityService.speak('$dataType$item $changeType com sucesso');
  }
}