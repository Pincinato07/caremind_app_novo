import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'medicamento_service.dart';
import 'rotina_service.dart';
import 'accessibility_service.dart';
import 'review_trigger_service.dart';
import '../models/medicamento.dart';
import '../core/errors/result.dart';

/// Serviço completo de interface de voz (Voice-First)
/// Integra Speech-to-Text (STT) e Text-to-Speech (TTS)
/// Processa comandos de voz para interação com medicamentos e rotinas
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isInitialized = false;
  bool _isAvailable = false;

  Function(String)? _onResult;
  Function(String)? _onError;

  /// Inicializa o serviço de voz
  Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;

    try {
      // Solicitar permissão de microfone
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        await speak(
            'Preciso de permissão para usar o microfone. Por favor, ative nas configurações.');
        _isAvailable = false;
        _isInitialized = true;
        return false;
      }

      // Verificar disponibilidade do STT
      _isAvailable = await _speech.initialize(
        onError: (error) {
          print('Erro STT: $error');
          _onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          print('Status STT: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );

      // Inicializar AccessibilityService para TTS
      await AccessibilityService.initialize();

      _isInitialized = true;
      return _isAvailable;
    } catch (e) {
      print('Erro ao inicializar VoiceService: $e');
      _isAvailable = false;
      _isInitialized = true;
      return false;
    }
  }

  /// Verifica se o serviço está disponível
  bool get isAvailable => _isAvailable && _isInitialized;

  /// Verifica se está ouvindo
  bool get isListening => _isListening;

  /// Inicia o reconhecimento de voz
  Future<void> startListening({
    Function(String)? onResult,
    Function(String)? onError,
  }) async {
    if (!isAvailable) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('Serviço de voz não disponível');
        return;
      }
    }

    if (_isListening) {
      await stopListening();
    }

    _onResult = onResult;
    _onError = onError;

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _isListening = false;
            _onResult?.call(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: 'pt_BR',
        // ignore: deprecated_member_use
        cancelOnError: true,
      );
    } catch (e) {
      _isListening = false;
      _onError?.call('Erro ao iniciar reconhecimento: $e');
    }
  }

  /// Para o reconhecimento de voz
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Cancela o reconhecimento de voz
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }

  /// Fala um texto usando TTS (respeita configuração de TTS)
  Future<void> speak(String text) async {
    // Verificar se TTS está habilitado
    // Delegar para AccessibilityService que já gerencia configurações e instância única
    await AccessibilityService.speak(text);
  }

  /// Para a fala atual
  Future<void> stopSpeaking() async {
    await AccessibilityService.stop();
  }

  /// Processa um comando de voz e executa a ação correspondente
  Future<VoiceCommandResult> processCommand(
    String command,
    String userId, {
    MedicamentoService? medicamentoService,
    RotinaService? rotinaService,
  }) async {
    final lowerCommand = command.toLowerCase().trim();

    // Comandos de confirmação de medicamento
    if (_matchesCommand(lowerCommand, [
      'já tomei o remédio',
      'tomei o remédio',
      'já tomei o medicamento',
      'tomei o medicamento',
      'confirma remédio',
      'confirma medicamento',
      'marquei como tomado',
      'remédio tomado',
      'medicamento tomado',
    ])) {
      return await _processarConfirmacaoMedicamento(
        userId,
        medicamentoService,
      );
    }

    // Comandos de confirmação de rotina
    if (_matchesCommand(lowerCommand, [
      'já fiz a rotina',
      'fiz a rotina',
      'confirma rotina',
      'rotina feita',
      'marquei a rotina',
      'rotina concluída',
    ])) {
      return await _processarConfirmacaoRotina(
        userId,
        rotinaService,
      );
    }

    // Comandos de listagem
    if (_matchesCommand(lowerCommand, [
      'quais remédios',
      'quais medicamentos',
      'lista remédios',
      'lista medicamentos',
      'meus remédios',
      'meus medicamentos',
    ])) {
      return await _processarListarMedicamentos(
        userId,
        medicamentoService,
      );
    }

    if (_matchesCommand(lowerCommand, [
      'quais rotinas',
      'lista rotinas',
      'minhas rotinas',
    ])) {
      return await _processarListarRotinas(
        userId,
        rotinaService,
      );
    }

    // Comandos de navegação
    if (_matchesCommand(lowerCommand, [
      'ir para medicamentos',
      'abrir medicamentos',
      'meus remédios',
      'ver remédios',
      'medicamentos',
    ])) {
      return VoiceCommandResult(
        success: true,
        message: 'Abrindo seus medicamentos...',
        action: VoiceAction.navigateToMedications,
      );
    }

    if (_matchesCommand(lowerCommand, [
      'ir para compromissos',
      'abrir compromissos',
      'meus compromissos',
      'ver compromissos',
      'compromissos',
    ])) {
      return VoiceCommandResult(
        success: true,
        message: 'Abrindo seus compromissos...',
        action: VoiceAction.navigateToAppointments,
      );
    }

    if (_matchesCommand(lowerCommand, [
      'ir para dashboard',
      'voltar ao início',
      'início',
      'menu principal',
      'tela inicial',
    ])) {
      return VoiceCommandResult(
        success: true,
        message: 'Voltando ao menu principal...',
        action: VoiceAction.navigateToDashboard,
      );
    }

    if (_matchesCommand(lowerCommand, [
      'ir para configurações',
      'abrir configurações',
      'configurações',
      'ajustes',
    ])) {
      return VoiceCommandResult(
        success: true,
        message: 'Abrindo configurações...',
        action: VoiceAction.navigateToSettings,
      );
    }

    if (_matchesCommand(lowerCommand, [
      'ligar para ajuda',
      'chamar ajuda',
      'emergência',
      'socorro',
      'ajuda',
    ])) {
      return VoiceCommandResult(
        success: true,
        message: 'Chamando ajuda...',
        action: VoiceAction.emergencyCall,
      );
    }

    // Comandos de ajuda
    if (_matchesCommand(lowerCommand, [
      'ajuda',
      'o que posso fazer',
      'comandos',
      'o que você faz',
    ])) {
      return VoiceCommandResult(
        success: true,
        message:
            'Você pode me pedir para: confirmar um remédio, confirmar uma rotina, listar seus remédios, listar suas rotinas, ir para medicamentos, ir para compromissos, voltar ao início, ir para configurações, ou chamar ajuda. O que deseja fazer?',
        action: VoiceAction.help,
      );
    }

    // Comando não reconhecido
    return VoiceCommandResult(
      success: false,
      message:
          'Desculpe, não entendi. Você pode me pedir para confirmar um remédio, confirmar uma rotina, listar itens, navegar entre telas ou chamar ajuda. Diga "ajuda" para ver todos os comandos.',
      action: VoiceAction.unknown,
    );
  }

  /// Verifica se o comando corresponde a algum dos padrões
  bool _matchesCommand(String command, List<String> patterns) {
    return patterns.any((pattern) =>
        command.contains(pattern) ||
        pattern.split(' ').every((word) => command.contains(word)));
  }

  /// Helper para processar sucesso na busca de medicamentos
  Future<VoiceCommandResult> _handleMedicamentosSuccess(
    List<Medicamento> medicamentos,
    MedicamentoService medicamentoService,
  ) async {
    if (medicamentos.isEmpty) {
      return VoiceCommandResult(
        success: true,
        message: 'Não encontrei nenhum remédio cadastrado.',
        action: VoiceAction.noPendingItems,
      );
    }

    // Se houver apenas um, confirmar automaticamente
    if (medicamentos.length == 1) {
      final medicamento = medicamentos.first;
      await medicamentoService.toggleConcluido(
        medicamento.id!,
        true,
        DateTime.now(),
      );

      // ✅ VERIFICAR TRIGGER DE AVALIAÇÃO (via voz)
      await ReviewTriggerService.incrementStreak();

      return VoiceCommandResult(
        success: true,
        message:
            'Entendido! Marquei o remédio "${medicamento.nome}" como tomado. Bom trabalho!',
        action: VoiceAction.medicationConfirmed,
        data: {'medicamento_id': medicamento.id},
      );
    }

    // Se houver múltiplos, listar e pedir confirmação
    final nomes = medicamentos.map((m) => m.nome).join(', ');
    return VoiceCommandResult(
      success: true,
      message:
          'Encontrei ${medicamentos.length} remédios: $nomes. Qual você tomou?',
      action: VoiceAction.multipleItems,
      data: {
        'medicamentos':
            medicamentos.map((m) => {'id': m.id, 'nome': m.nome}).toList()
      },
    );
  }

  /// Processa confirmação de medicamento
  Future<VoiceCommandResult> _processarConfirmacaoMedicamento(
    String userId,
    MedicamentoService? medicamentoService,
  ) async {
    if (medicamentoService == null) {
      return VoiceCommandResult(
        success: false,
        message: 'Serviço de medicamentos não disponível.',
        action: VoiceAction.error,
      );
    }

    try {
      // Buscar todos os medicamentos
      final medicamentosResult =
          await medicamentoService.getMedicamentos(userId);

      return switch (medicamentosResult) {
        Success(:final data) => await _handleMedicamentosSuccess(
            data,
            medicamentoService,
          ),
        Failure() => VoiceCommandResult(
            success: false,
            message:
                'Tive um problema ao processar sua solicitação. Tente novamente.',
            action: VoiceAction.error,
          ),
      };
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message:
            'Tive um problema ao processar sua solicitação. Tente novamente.',
        action: VoiceAction.error,
      );
    }
  }

  /// Processa confirmação de rotina
  Future<VoiceCommandResult> _processarConfirmacaoRotina(
    String userId,
    RotinaService? rotinaService,
  ) async {
    if (rotinaService == null) {
      return VoiceCommandResult(
        success: false,
        message: 'Serviço de rotinas não disponível.',
        action: VoiceAction.error,
      );
    }

    try {
      // Buscar rotinas pendentes
      final rotinas = await rotinaService.getRotinas(userId);
      // CORRIGIDO: Usar concluido (boolean) em vez de concluida (tabela usa concluido)
      final rotinasPendentes =
          rotinas.where((r) => (r['concluido'] ?? r['concluida'] ?? false) == false).toList();

      if (rotinasPendentes.isEmpty) {
        return VoiceCommandResult(
          success: true,
          message:
              'Não encontrei nenhuma rotina pendente para confirmar agora.',
          action: VoiceAction.noPendingItems,
        );
      }

      // Se houver apenas uma, confirmar automaticamente
      if (rotinasPendentes.length == 1) {
        final rotina = rotinasPendentes.first;
        await rotinaService.toggleConcluida(rotina['id'], true);

        return VoiceCommandResult(
          success: true,
          message:
              'Entendido! Marquei a rotina "${rotina['titulo']}" como concluída. Bom trabalho!',
          action: VoiceAction.routineConfirmed,
          data: {'rotina_id': rotina['id']},
        );
      }

      // Se houver múltiplas, listar e pedir confirmação
      final titulos = rotinasPendentes.map((r) => r['titulo']).join(', ');
      return VoiceCommandResult(
        success: true,
        message:
            'Encontrei ${rotinasPendentes.length} rotinas pendentes: $titulos. Qual você concluiu?',
        action: VoiceAction.multipleItems,
        data: {
          'rotinas': rotinasPendentes
              .map((r) => {'id': r['id'], 'titulo': r['titulo']})
              .toList()
        },
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message:
            'Tive um problema ao processar sua solicitação. Tente novamente.',
        action: VoiceAction.error,
      );
    }
  }

  /// Helper para processar sucesso na listagem de medicamentos
  VoiceCommandResult _handleListarMedicamentosSuccess(
    List<Medicamento> medicamentos,
  ) {
    if (medicamentos.isEmpty) {
      return VoiceCommandResult(
        success: true,
        message: 'Você não tem remédios cadastrados ainda.',
        action: VoiceAction.listEmpty,
      );
    }

    String message =
        'Você tem ${medicamentos.length} remédio(s) cadastrado(s): ';
    message += medicamentos.map((m) => m.nome).join(', ');

    return VoiceCommandResult(
      success: true,
      message: message,
      action: VoiceAction.listMedications,
      data: {
        'medicamentos':
            medicamentos.map((m) => {'id': m.id, 'nome': m.nome}).toList()
      },
    );
  }

  /// Processa listagem de medicamentos
  Future<VoiceCommandResult> _processarListarMedicamentos(
    String userId,
    MedicamentoService? medicamentoService,
  ) async {
    if (medicamentoService == null) {
      return VoiceCommandResult(
        success: false,
        message: 'Serviço de medicamentos não disponível.',
        action: VoiceAction.error,
      );
    }

    try {
      final medicamentosResult =
          await medicamentoService.getMedicamentos(userId);

      return switch (medicamentosResult) {
        Success(:final data) => _handleListarMedicamentosSuccess(data),
        Failure() => VoiceCommandResult(
            success: false,
            message:
                'Tive um problema ao buscar seus remédios. Tente novamente.',
            action: VoiceAction.error,
          ),
      };
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message: 'Tive um problema ao buscar seus remédios. Tente novamente.',
        action: VoiceAction.error,
      );
    }
  }

  /// Processa listagem de rotinas
  Future<VoiceCommandResult> _processarListarRotinas(
    String userId,
    RotinaService? rotinaService,
  ) async {
    if (rotinaService == null) {
      return VoiceCommandResult(
        success: false,
        message: 'Serviço de rotinas não disponível.',
        action: VoiceAction.error,
      );
    }

    try {
      final rotinas = await rotinaService.getRotinas(userId);

      if (rotinas.isEmpty) {
        return VoiceCommandResult(
          success: true,
          message: 'Você não tem rotinas cadastradas ainda.',
          action: VoiceAction.listEmpty,
        );
      }

      // CORRIGIDO: Usar concluido (boolean) em vez de concluida (tabela usa concluido)
      final pendentes = rotinas.where((r) => (r['concluido'] ?? r['concluida'] ?? false) == false).toList();
      final concluidas = rotinas.where((r) => (r['concluido'] ?? r['concluida'] ?? false) == true).toList();

      String message = 'Você tem ${rotinas.length} rotina(s) cadastrada(s). ';

      if (pendentes.isNotEmpty) {
        message +=
            '${pendentes.length} pendente(s): ${pendentes.map((r) => r['titulo']).join(', ')}. ';
      }

      if (concluidas.isNotEmpty) {
        message += '${concluidas.length} já concluída(s) hoje.';
      }

      return VoiceCommandResult(
        success: true,
        message: message,
        action: VoiceAction.listRoutines,
        data: {
          'rotinas': rotinas
              .map((r) => {
                    'id': r['id'],
                    'titulo': r['titulo'],
                    'concluido': r['concluido'] ?? r['concluida'] ?? false
                  })
              .toList()
        },
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message: 'Tive um problema ao buscar suas rotinas. Tente novamente.',
        action: VoiceAction.error,
      );
    }
  }

  /// Limpa recursos
  void dispose() {
    _speech.cancel();
    AccessibilityService.stop();
    _isListening = false;
  }
}

/// Resultado do processamento de comando de voz
class VoiceCommandResult {
  final bool success;
  final String message;
  final VoiceAction action;
  final Map<String, dynamic>? data;

  VoiceCommandResult({
    required this.success,
    required this.message,
    required this.action,
    this.data,
  });
}

/// Ações possíveis de comandos de voz
enum VoiceAction {
  medicationConfirmed,
  routineConfirmed,
  listMedications,
  listRoutines,
  navigateToMedications,
  navigateToAppointments,
  navigateToDashboard,
  navigateToSettings,
  emergencyCall,
  multipleItems,
  noPendingItems,
  listEmpty,
  help,
  error,
  unknown,
}
