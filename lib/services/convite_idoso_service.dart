import 'dart:async' hide TimeoutException;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/result.dart';

/// Resultado do processamento de um convite
class ConviteResultado {
  final bool sucesso;
  final String? idIdoso;
  final String? nomeIdoso;
  final String? emailIdoso;
  final String? mensagem;
  final String? erro;

  ConviteResultado({
    required this.sucesso,
    this.idIdoso,
    this.nomeIdoso,
    this.emailIdoso,
    this.mensagem,
    this.erro,
  });

  factory ConviteResultado.sucesso({
    required String idIdoso,
    required String nomeIdoso,
    String? emailIdoso,
    String? mensagem,
  }) {
    return ConviteResultado(
      sucesso: true,
      idIdoso: idIdoso,
      nomeIdoso: nomeIdoso,
      emailIdoso: emailIdoso,
      mensagem: mensagem ?? 'Convite processado com sucesso!',
    );
  }

  factory ConviteResultado.erro(String erro) {
    return ConviteResultado(
      sucesso: false,
      erro: erro,
    );
  }
}

/// Serviço para processar convites de login para idosos
class ConviteIdosoService {
  final SupabaseClient _client;

  ConviteIdosoService(this._client);

  /// Valida um convite pelo token ou código usando Edge Function
  /// Isso permite obter o email do idoso de forma segura
  Future<ConviteResultado> validarConvite(String tokenOuCodigo) async {
    try {
      // Validação de entrada
      if (tokenOuCodigo.isEmpty || tokenOuCodigo.trim().isEmpty) {
        return ConviteResultado.erro('Token ou código do convite não pode ser vazio.');
      }

      // Sanitizar entrada (remover espaços)
      final sanitized = tokenOuCodigo.trim();

      // Chamar Edge Function para validar convite e obter email
      final response = await _client.functions.invoke(
        'validar-convite-idoso',
        body: {'token_ou_codigo': sanitized},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(message: 'Tempo excedido ao validar convite');
        },
      );

      // Verificar status da resposta
      if (response.status != 200) {
        final errorMessage =
            'Erro ao validar convite (status ${response.status})';
        throw Exception(errorMessage);
      }

      if (response.data == null) {
        throw Exception('Resposta vazia da Edge Function. Tente novamente.');
      }

      // Validar tipo da resposta
      if (response.data is! Map<String, dynamic>) {
        throw Exception('Formato de resposta inválido da Edge Function');
      }

      final data = response.data as Map<String, dynamic>;

      // Verificar se há erro na resposta
      if (data.containsKey('error')) {
        final errorMsg =
            data['error'] as String? ?? 'Erro desconhecido ao validar convite';
        return ConviteResultado.erro(errorMsg);
      }

      // Verificar se há sucesso
      if (data.containsKey('success') && data['success'] != true) {
        return ConviteResultado.erro('Falha ao validar convite. Tente novamente.');
      }

      // Extrair dados do convite
      final conviteData = data['convite'] as Map<String, dynamic>?;
      if (conviteData == null) {
        return ConviteResultado.erro(
            'Dados do convite não encontrados na resposta. Tente novamente.');
      }

      // Validar campos obrigatórios
      final idIdoso = conviteData['id_idoso'] as String?;
      final nomeIdoso = conviteData['nome_idoso'] as String? ?? 'Idoso';
      final emailIdoso = conviteData['email_idoso'] as String?;

      if (idIdoso == null || idIdoso.isEmpty) {
        return ConviteResultado.erro('ID do idoso não encontrado no convite.');
      }

      if (emailIdoso == null || emailIdoso.isEmpty) {
        return ConviteResultado.erro(
            'Email do idoso não encontrado. Entre em contato com o familiar.');
      }

      return ConviteResultado.sucesso(
        idIdoso: idIdoso,
        nomeIdoso: nomeIdoso,
        emailIdoso: emailIdoso,
        mensagem: 'Convite válido! Você pode fazer login agora.',
      );
    } on TimeoutException catch (e) {
      debugPrint('Timeout ao validar convite: $e');
      return ConviteResultado.erro(
          'Tempo de espera excedido. Verifique sua conexão e tente novamente.');
    } catch (error) {
      debugPrint('Erro ao validar convite: $error');
      
      // Mensagens mais amigáveis para erros comuns
      String errorMessage;
      final appException = ErrorHandler.toAppException(error);
      
      if (appException.message.contains('network') ||
          appException.message.contains('conexão') ||
          appException.message.contains('connection') ||
          appException.message.contains('Tempo excedido')) {
        errorMessage =
            'Erro de conexão. Verifique sua internet e tente novamente.';
      } else {
        errorMessage = appException.message;
      }
      
      return ConviteResultado.erro(errorMessage);
    }
  }

  /// Marca um convite como usado após o login bem-sucedido
  Future<void> marcarConviteComoUsado(
      String tokenOuCodigo, String userId) async {
    try {
      final isToken = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(tokenOuCodigo);

      if (isToken) {
        await _client.from('convites_idosos').update({
          'usado': true,
          'usado_em': DateTime.now().toIso8601String(),
          'usado_por': userId,
        }).eq('token', tokenOuCodigo);
      } else {
        await _client.from('convites_idosos').update({
          'usado': true,
          'usado_em': DateTime.now().toIso8601String(),
          'usado_por': userId,
        }).eq('codigo_convite', tokenOuCodigo.toUpperCase());
      }
    } catch (error) {
      debugPrint('Erro ao marcar convite como usado: $error');
      // Não lançar erro - é apenas uma atualização de status
    }
  }

  /// Processa um convite completo: valida e retorna dados para login
  Future<ConviteResultado> processarConvite(String tokenOuCodigo) async {
    final resultado = await validarConvite(tokenOuCodigo);
    return resultado;
  }

  /// Gera um novo convite de login para um idoso
  Future<Result<ConviteData>> gerarConvite(String idIdoso) async {
    try {
      if (idIdoso.isEmpty) {
        return Failure(ValidationException(
          message: 'ID do idoso não pode ser vazio',
        ));
      }

      final session = _client.auth.currentSession;
      if (session == null) {
        return Failure(AuthenticationException(
          message: 'Usuário não autenticado. Faça login novamente.',
        ));
      }

      final response = await _client.functions.invoke(
        'gerar-convite-idoso',
        body: {'id_idoso': idIdoso},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(message: 'Tempo excedido ao gerar convite');
        },
      );

      // Verificar status da resposta
      if (response.status != 200) {
        final errorMessage =
            'Erro ao gerar convite (status ${response.status})';
        throw Exception(errorMessage);
      }

      if (response.data == null) {
        throw Exception('Resposta vazia da Edge Function. Tente novamente.');
      }

      // Validar tipo da resposta
      if (response.data is! Map<String, dynamic>) {
        throw Exception('Formato de resposta inválido da Edge Function');
      }

      final data = response.data as Map<String, dynamic>;

      // Verificar se há erro na resposta
      if (data.containsKey('error')) {
        final errorMsg =
            data['error'] as String? ?? 'Erro desconhecido ao gerar convite';
        throw Exception(errorMsg);
      }

      // Verificar se há sucesso
      if (data.containsKey('success') && data['success'] != true) {
        throw Exception('Falha ao gerar convite. Tente novamente.');
      }

      // Extrair dados do convite
      final conviteData = data['convite'] as Map<String, dynamic>?;
      if (conviteData == null) {
        throw Exception(
            'Dados do convite não encontrados na resposta. Tente novamente.');
      }

      // Validar campos obrigatórios antes de criar o objeto
      final requiredFields = [
        'id',
        'codigo_convite',
        'token',
        'link_completo',
        'expira_em',
        'id_idoso'
      ];
      for (final field in requiredFields) {
        if (!conviteData.containsKey(field) || conviteData[field] == null) {
          throw Exception(
              'Campo obrigatório "$field" não encontrado na resposta do convite');
        }
      }

      return Success(ConviteData.fromJson(conviteData));
    } on TimeoutException catch (e) {
      debugPrint('Timeout ao gerar convite para idoso: $idIdoso');
      return Failure(TimeoutException(
        message:
            'Tempo de espera excedido. Verifique sua conexão e tente novamente.',
        originalError: e,
      ));
    } on AppException catch (e) {
      return Failure(e);
    } catch (error) {
      // Tratar timeout do Future.timeout
      if (error.toString().contains('Tempo excedido')) {
        return Failure(TimeoutException(
          message:
              'Tempo de espera excedido. Verifique sua conexão e tente novamente.',
          originalError: error,
        ));
      }
      debugPrint('Erro ao gerar convite para idoso $idIdoso: $error');
      final appException = ErrorHandler.toAppException(error);

      // Mensagens mais amigáveis para erros comuns
      String errorMessage;
      if (appException.message.contains('permission') ||
          appException.message.contains('permissão') ||
          appException.message.contains('403')) {
        errorMessage =
            'Você não tem permissão para gerar convite para este idoso.';
      } else if (appException.message.contains('not found') ||
          appException.message.contains('não encontrado') ||
          appException.message.contains('404')) {
        errorMessage =
            'Idoso não encontrado. Verifique se o idoso ainda existe.';
      } else if (appException.message.contains('network') ||
          appException.message.contains('conexão') ||
          appException.message.contains('connection')) {
        errorMessage =
            'Erro de conexão. Verifique sua internet e tente novamente.';
      } else {
        errorMessage = appException.message;
      }

      return Failure(UnknownException(message: errorMessage));
    }
  }
}

/// Dados de um convite gerado
class ConviteData {
  final String id;
  final String idIdoso;
  final String codigoConvite;
  final String token;
  final String linkCompleto;
  final String linkWeb;
  final String? linkApp;
  final String expiraEm;
  final String nomeIdoso;
  final String criadoPor;
  final bool usado;
  final String? usadoEm;
  final String createdAt;

  ConviteData({
    required this.id,
    required this.idIdoso,
    required this.codigoConvite,
    required this.token,
    required this.linkCompleto,
    required this.linkWeb,
    this.linkApp,
    required this.expiraEm,
    required this.nomeIdoso,
    required this.criadoPor,
    required this.usado,
    this.usadoEm,
    required this.createdAt,
  });

  factory ConviteData.fromJson(Map<String, dynamic> json) {
    try {
      // Validar campos obrigatórios
      final requiredFields = {
        'id': json['id'],
        'id_idoso': json['id_idoso'],
        'codigo_convite': json['codigo_convite'],
        'token': json['token'],
        'link_completo': json['link_completo'],
        'expira_em': json['expira_em'],
      };

      for (final entry in requiredFields.entries) {
        if (entry.value == null) {
          throw FormatException(
              'Campo obrigatório "${entry.key}" está nulo no JSON do convite');
        }
      }

      // Validar tipos
      if (json['id'] is! String) {
        throw FormatException('Campo "id" deve ser uma String');
      }
      if (json['codigo_convite'] is! String ||
          (json['codigo_convite'] as String).isEmpty) {
        throw FormatException(
            'Campo "codigo_convite" deve ser uma String não vazia');
      }
      if (json['token'] is! String || (json['token'] as String).isEmpty) {
        throw FormatException('Campo "token" deve ser uma String não vazia');
      }
      if (json['link_completo'] is! String ||
          (json['link_completo'] as String).isEmpty) {
        throw FormatException(
            'Campo "link_completo" deve ser uma String não vazia');
      }

      // Validar formato do link (aceita caremind:// ou https://)
      final linkCompleto = json['link_completo'] as String;
      if (!linkCompleto.startsWith('caremind://') && !linkCompleto.startsWith('https://')) {
        throw FormatException('Link do convite deve começar com "caremind://" ou "https://"');
      }

      // Validar formato da data de expiração
      try {
        DateTime.parse(json['expira_em'] as String);
      } catch (e) {
        throw FormatException(
            'Campo "expira_em" não é uma data válida: ${json['expira_em']}');
      }

      return ConviteData(
        id: json['id'] as String,
        idIdoso: json['id_idoso'] as String,
        codigoConvite: json['codigo_convite'] as String,
        token: json['token'] as String,
        linkCompleto: linkCompleto,
        linkWeb: json['link_web'] as String? ?? linkCompleto,
        linkApp: json['link_app'] as String?,
        expiraEm: json['expira_em'] as String,
        nomeIdoso: json['nome_idoso'] as String? ?? 'Idoso',
        criadoPor: json['criado_por'] as String? ?? '',
        usado: json['usado'] as bool? ?? false,
        usadoEm: json['usado_em'] as String?,
        createdAt:
            json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );
    } on FormatException catch (e) {
      debugPrint('Erro ao fazer parse do JSON do convite: $e');
      rethrow;
    } catch (e) {
      debugPrint('Erro inesperado ao fazer parse do JSON do convite: $e');
      throw FormatException('Erro ao processar dados do convite: $e');
    }
  }
}
