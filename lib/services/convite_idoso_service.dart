import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';
import '../core/errors/app_exception.dart';

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

  /// Valida um convite pelo token ou código
  Future<ConviteResultado> validarConvite(String tokenOuCodigo) async {
    try {
      // Determinar se é token (UUID) ou código (alfanumérico)
      final isToken = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(tokenOuCodigo);

      // Buscar convite
      var query = _client
          .from('convites_idosos')
          .select('''
            id,
            id_idoso,
            codigo_convite,
            token,
            expira_em,
            usado,
            perfis!convites_idosos_id_idoso_fkey (
              nome,
              user_id
            )
          ''');

      if (isToken) {
        query = query.eq('token', tokenOuCodigo);
      } else {
        query = query.eq('codigo_convite', tokenOuCodigo.toUpperCase());
      }

      final response = await query.maybeSingle();

      if (response == null) {
        return ConviteResultado.erro('Convite não encontrado.');
      }

      // Verificar se já foi usado
      if (response['usado'] == true) {
        return ConviteResultado.erro('Este convite já foi utilizado.');
      }

      // Verificar se está expirado
      try {
        final expiraEm = DateTime.parse(response['expira_em'] as String);
        final agora = DateTime.now();
        if (agora.isAfter(expiraEm)) {
          return ConviteResultado.erro('Este convite expirou.');
        }
      } catch (e) {
        debugPrint('Erro ao parsear data de expiração: $e');
        return ConviteResultado.erro('Erro ao validar data de expiração do convite.');
      }

      // Extrair dados do perfil
      final perfil = response['perfis'];
      final nomeIdoso = perfil?['nome'] ?? 'Idoso';
      final user_id = perfil?['user_id'];

      if (user_id == null) {
        return ConviteResultado.erro('Perfil do idoso não encontrado.');
      }

      // Buscar email do usuário
      final authUserResponse = await _client.auth.admin.getUserById(user_id);
      final emailIdoso = authUserResponse.user?.email;

      return ConviteResultado.sucesso(
        idIdoso: response['id_idoso'],
        nomeIdoso: nomeIdoso,
        emailIdoso: emailIdoso,
        mensagem: 'Convite válido! Você pode fazer login agora.',
      );
    } catch (error) {
      debugPrint('Erro ao validar convite: $error');
      return ConviteResultado.erro(
        ErrorHandler.toAppException(error).message,
      );
    }
  }

  /// Marca um convite como usado após o login bem-sucedido
  Future<void> marcarConviteComoUsado(String tokenOuCodigo, String userId) async {
    try {
      final isToken = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(tokenOuCodigo);

      if (isToken) {
        await _client
            .from('convites_idosos')
            .update({
              'usado': true,
              'usado_em': DateTime.now().toIso8601String(),
              'usado_por': userId,
            })
            .eq('token', tokenOuCodigo);
      } else {
        await _client
            .from('convites_idosos')
            .update({
              'usado': true,
              'usado_em': DateTime.now().toIso8601String(),
              'usado_por': userId,
            })
            .eq('codigo_convite', tokenOuCodigo.toUpperCase());
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
  /// Retorna os dados do convite gerado (código, token, link)
  /// 
  /// Lança [AppException] em caso de erro
  Future<ConviteData> gerarConvite(String idIdoso) async {
    try {
      // Validação de entrada
      if (idIdoso.isEmpty) {
        throw Exception('ID do idoso não pode ser vazio');
      }

      // Verificar se o cliente está autenticado
      final session = _client.auth.currentSession;
      if (session == null) {
        throw Exception('Usuário não autenticado. Faça login novamente.');
      }

      final response = await _client.functions.invoke(
        'gerar-convite-idoso',
        body: {
          'id_idoso': idIdoso,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Tempo de espera excedido. Verifique sua conexão e tente novamente.');
        },
      );

      // Verificar status da resposta
      if (response.status != 200) {
        final errorMessage = 'Erro ao gerar convite (status ${response.status})';
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
        final errorMsg = data['error'] as String? ?? 'Erro desconhecido ao gerar convite';
        throw Exception(errorMsg);
      }

      // Verificar se há sucesso
      if (data.containsKey('success') && data['success'] != true) {
        throw Exception('Falha ao gerar convite. Tente novamente.');
      }

      // Extrair dados do convite
      final conviteData = data['convite'] as Map<String, dynamic>?;
      if (conviteData == null) {
        throw Exception('Dados do convite não encontrados na resposta. Tente novamente.');
      }

      // Validar campos obrigatórios antes de criar o objeto
      final requiredFields = ['id', 'codigo_convite', 'token', 'link_completo', 'expira_em', 'id_idoso'];
      for (final field in requiredFields) {
        if (!conviteData.containsKey(field) || conviteData[field] == null) {
          throw Exception('Campo obrigatório "$field" não encontrado na resposta do convite');
        }
      }

      return ConviteData.fromJson(conviteData);
    } on TimeoutException {
      debugPrint('Timeout ao gerar convite para idoso: $idIdoso');
      throw Exception('Tempo de espera excedido. Verifique sua conexão e tente novamente.');
    } on AppException {
      // Re-lançar AppException sem modificação
      rethrow;
    } catch (error) {
      debugPrint('Erro ao gerar convite para idoso $idIdoso: $error');
      final appException = ErrorHandler.toAppException(error);
      
      // Mensagens mais amigáveis para erros comuns
      if (appException.message.contains('permission') || 
          appException.message.contains('permissão') ||
          appException.message.contains('403')) {
        throw Exception('Você não tem permissão para gerar convite para este idoso.');
      } else if (appException.message.contains('not found') || 
                 appException.message.contains('não encontrado') ||
                 appException.message.contains('404')) {
        throw Exception('Idoso não encontrado. Verifique se o idoso ainda existe.');
      } else if (appException.message.contains('network') || 
                 appException.message.contains('conexão') ||
                 appException.message.contains('connection')) {
        throw Exception('Erro de conexão. Verifique sua internet e tente novamente.');
      }
      
      throw appException;
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
          throw FormatException('Campo obrigatório "${entry.key}" está nulo no JSON do convite');
        }
      }

      // Validar tipos
      if (json['id'] is! String) {
        throw FormatException('Campo "id" deve ser uma String');
      }
      if (json['codigo_convite'] is! String || (json['codigo_convite'] as String).isEmpty) {
        throw FormatException('Campo "codigo_convite" deve ser uma String não vazia');
      }
      if (json['token'] is! String || (json['token'] as String).isEmpty) {
        throw FormatException('Campo "token" deve ser uma String não vazia');
      }
      if (json['link_completo'] is! String || (json['link_completo'] as String).isEmpty) {
        throw FormatException('Campo "link_completo" deve ser uma String não vazia');
      }

      // Validar formato do link
      final linkCompleto = json['link_completo'] as String;
      if (!linkCompleto.startsWith('caremind://')) {
        throw FormatException('Link do convite deve começar com "caremind://"');
      }

      // Validar formato da data de expiração
      try {
        DateTime.parse(json['expira_em'] as String);
      } catch (e) {
        throw FormatException('Campo "expira_em" não é uma data válida: ${json['expira_em']}');
      }

      return ConviteData(
        id: json['id'] as String,
        idIdoso: json['id_idoso'] as String,
        codigoConvite: json['codigo_convite'] as String,
        token: json['token'] as String,
        linkCompleto: linkCompleto,
        linkWeb: json['link_web'] as String? ?? linkCompleto,
        expiraEm: json['expira_em'] as String,
        nomeIdoso: json['nome_idoso'] as String? ?? 'Idoso',
        criadoPor: json['criado_por'] as String? ?? '',
        usado: json['usado'] as bool? ?? false,
        usadoEm: json['usado_em'] as String?,
        createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
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

