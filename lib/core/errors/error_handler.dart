import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_exception.dart';
import 'failure.dart';

/// Utilitário para converter exceções do Supabase e outras em exceções/Falhas personalizadas
///
/// REFATORADO: Agora suporta erros estruturados do backend com códigos padronizados
class ErrorHandler {
  /// Converte uma resposta de erro estruturada do backend em AppException
  ///
  /// Espera um JSON com o formato:
  /// ```json
  /// {
  ///   "error": "string",
  ///   "code": "ERROR_CODE",
  ///   "message": "Mensagem amigável",
  ///   "details": { ... }  // opcional
  /// }
  /// ```
  static AppException fromStructuredError(Map<String, dynamic> errorResponse) {
    final code = errorResponse['code'] as String?;
    final message = errorResponse['message'] as String? ?? 'Erro desconhecido';
    final details = errorResponse['details'] as Map<String, dynamic>?;

    // Se não tem código, retornar exceção genérica
    if (code == null) {
      return UnknownException(
        message: message,
        originalError: errorResponse,
      );
    }

    // Mapear códigos de erro específicos para exceções tipadas
    switch (code) {
      // Rate Limiting
      case 'RATE_LIMIT':
      case 'TOO_MANY_REQUESTS':
        return RateLimitException(
          message: message,
          code: code,
          retryAfter:
              errorResponse['retry_after'] as int? ?? 900, // 15 min padrão
          blockedUntil: errorResponse['blocked_until'] != null
              ? DateTime.tryParse(errorResponse['blocked_until'] as String)
              : null,
          minutosRestantes: errorResponse['minutos_restantes'] as int?,
          limit: errorResponse['limit'] as int?,
          remaining: errorResponse['remaining'] as int?,
          originalError: errorResponse,
        );

      // Claim Profile Specific
      case 'INVALID_CODE':
        return ClaimProfileException(
          message: message,
          code: code,
          errorCode: ClaimProfileErrorCode.invalidCode,
          tentativasRestantes: details?['tentativas_restantes'] as int?,
          originalError: errorResponse,
        );

      case 'CODE_EXPIRED':
        return ClaimProfileException(
          message: message,
          code: code,
          errorCode: ClaimProfileErrorCode.codeExpired,
          originalError: errorResponse,
        );

      case 'CODE_NOT_FOUND':
        return ClaimProfileException(
          message: message,
          code: code,
          errorCode: ClaimProfileErrorCode.codeNotFound,
          originalError: errorResponse,
        );

      case 'ALREADY_CLAIMED':
        return ClaimProfileException(
          message: message,
          code: code,
          errorCode: ClaimProfileErrorCode.alreadyClaimed,
          originalError: errorResponse,
        );

      case 'INVALID_ACTION':
        return ClaimProfileException(
          message: message,
          code: code,
          errorCode: ClaimProfileErrorCode.invalidAction,
          originalError: errorResponse,
        );

      case 'PROFILE_NOT_VIRTUAL':
        return ClaimProfileException(
          message: message,
          code: code,
          errorCode: ClaimProfileErrorCode.profileNotVirtual,
          originalError: errorResponse,
        );

      case 'LINK_EXISTS':
        return ClaimProfileException(
          message: message,
          code: code,
          errorCode: ClaimProfileErrorCode.linkExists,
          originalError: errorResponse,
        );

      case 'INVALID_PROFILE_TYPE':
        return ClaimProfileException(
          message: message,
          code: code,
          errorCode: ClaimProfileErrorCode.invalidProfileType,
          originalError: errorResponse,
        );

      // Authentication
      case 'UNAUTHORIZED':
      case 'TOKEN_EXPIRED':
      case 'TOKEN_INVALID':
      case 'AUTHENTICATION_REQUIRED':
        return AuthenticationException(
          message: message,
          code: code,
          originalError: errorResponse,
        );

      // Validation
      case 'INVALID_INPUT':
      case 'MISSING_FIELD':
      case 'INVALID_FORMAT':
        return ValidationException(
          message: message,
          code: code,
          originalError: errorResponse,
        );

      // Not Found
      case 'NOT_FOUND':
      case 'RESOURCE_NOT_FOUND':
      case 'PROFILE_NOT_FOUND':
      case 'ORGANIZATION_NOT_FOUND':
        return DatabaseException(
          message: message,
          code: code,
          originalError: errorResponse,
        );

      // Conflict/Duplicate
      case 'DUPLICATE_ENTRY':
      case 'ALREADY_EXISTS':
        return ConflictException(
          message: message,
          code: code,
          originalError: errorResponse,
        );

      // Database
      case 'DATABASE_ERROR':
      case 'INTERNAL_ERROR':
      case 'CONFIGURATION_ERROR':
        return DatabaseException(
          message: message,
          code: code,
          originalError: errorResponse,
        );

      // Network
      case 'NETWORK_ERROR':
      case 'SERVICE_UNAVAILABLE':
        return NetworkException(
          message: message,
          code: code,
          originalError: errorResponse,
        );

      case 'TIMEOUT':
        return TimeoutException(
          message: message,
          code: code,
          originalError: errorResponse,
        );

      // Default
      default:
        return UnknownException(
          message: message,
          code: code,
          originalError: errorResponse,
        );
    }
  }

  /// Converte uma exceção em uma AppException
  static AppException toAppException(dynamic error) {
    if (error is AppException) {
      return error;
    }

    if (error is PostgrestException) {
      return DatabaseException(
        message: _extractPostgrestMessage(error),
        code: error.code,
        originalError: error,
      );
    }

    if (error is AuthException) {
      String message = _translateAuthErrorMessage(error.message);
      return AuthenticationException(
        message: message,
        code: error.statusCode?.toString(),
        originalError: error,
      );
    }

    if (error is StorageException) {
      return DatabaseException(
        message: 'Erro de armazenamento: ${error.message}',
        code: error.statusCode?.toString(),
        originalError: error,
      );
    }

    if (error is FunctionException) {
      return DatabaseException(
        message: 'Erro na função: ${error.toString()}',
        code: null, // FunctionException não tem statusCode
        originalError: error,
      );
    }

    // Erros de rede genéricos
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return NetworkException(
        message: 'Erro de conexão. Verifique sua internet e tente novamente.',
        originalError: error,
      );
    }

    // Erro desconhecido
    String message = _translateGenericError(error.toString());
    return UnknownException(
      message: message,
      originalError: error,
    );
  }

  /// Traduz mensagens de erro de autenticação para português
  static String _translateAuthErrorMessage(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (lowerMessage.contains('invalid credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (lowerMessage.contains('user not found')) {
      return 'Usuário não encontrado. Verifique o e-mail informado.';
    }
    if (lowerMessage.contains('email already registered')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (lowerMessage.contains('weak password')) {
      return 'Senha muito fraca. Use pelo menos 6 caracteres.';
    }
    if (lowerMessage.contains('email not confirmed')) {
      return 'E-mail não confirmado. Verifique sua caixa de entrada.';
    }
    if (lowerMessage.contains('too many requests')) {
      return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
    }
    if (lowerMessage.contains('bad request') || lowerMessage.contains('400')) {
      return 'Dados inválidos. Verifique seu e-mail e senha.';
    }
    if (lowerMessage.contains('unauthorized') || lowerMessage.contains('401')) {
      return 'Não autorizado. Verifique suas credenciais.';
    }
    if (lowerMessage.contains('forbidden') || lowerMessage.contains('403')) {
      return 'Acesso negado.';
    }
    if (lowerMessage.contains('not found') || lowerMessage.contains('404')) {
      return 'Recurso não encontrado.';
    }

    // Se não for uma mensagem conhecida, retorna a original
    return message;
  }

  /// Traduz mensagens de erro genéricas para português
  static String _translateGenericError(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('bad request') || lowerMessage.contains('400')) {
      return 'Dados inválidos. Verifique as informações informadas.';
    }
    if (lowerMessage.contains('unauthorized') || lowerMessage.contains('401')) {
      return 'Não autorizado. Faça login novamente.';
    }
    if (lowerMessage.contains('forbidden') || lowerMessage.contains('403')) {
      return 'Acesso negado.';
    }
    if (lowerMessage.contains('not found') || lowerMessage.contains('404')) {
      return 'Recurso não encontrado.';
    }
    if (lowerMessage.contains('timeout')) {
      return 'Tempo esgotado. Verifique sua conexão e tente novamente.';
    }
    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection')) {
      return 'Erro de conexão. Verifique sua internet.';
    }
    if (lowerMessage.contains('socket')) {
      return 'Erro de conexão. Verifique sua internet.';
    }

    return message;
  }

  /// Converte uma exceção em uma Failure
  static Failure toFailure(dynamic error) {
    final appException = toAppException(error);

    if (appException is NetworkException) {
      return NetworkFailure(
        message: appException.message,
        code: appException.code,
        exception: appException,
      );
    }

    if (appException is AuthenticationException) {
      return AuthenticationFailure(
        message: appException.message,
        code: appException.code,
        exception: appException,
      );
    }

    if (appException is DatabaseException) {
      return DatabaseFailure(
        message: appException.message,
        code: appException.code,
        exception: appException,
      );
    }

    if (appException is ValidationException) {
      return ValidationFailure(
        message: appException.message,
        code: appException.code,
        exception: appException,
      );
    }

    return UnknownFailure(
      message: appException.message,
      code: appException.code,
      exception: appException,
    );
  }

  /// Extrai mensagem amigável de um PostgrestException
  static String _extractPostgrestMessage(PostgrestException error) {
    // Mensagens mais amigáveis baseadas no código de erro
    switch (error.code) {
      case 'PGRST116':
        return 'Nenhum resultado encontrado.';
      case '23505':
        return 'Este registro já existe.';
      case '23503':
        return 'Não é possível realizar esta operação devido a dependências.';
      case '23502':
        return 'Campos obrigatórios não foram preenchidos.';
      case '42P01':
        return 'Tabela não encontrada.';
      case 'PGRST301':
      case 'PGRST302':
        return 'Erro na requisição. Verifique os dados enviados.';
      default:
        // Tenta extrair mensagem do detalhe, senão usa a mensagem padrão
        if (error.details != null && error.details.toString().isNotEmpty) {
          final details = error.details.toString();
          // Se contém informações sobre campos faltando, destacar
          if (details.toLowerCase().contains('null value') ||
              details.toLowerCase().contains('violates not-null')) {
            return 'Campos obrigatórios não foram preenchidos. Verifique todos os campos.';
          }
          // Traduzir mensagens comuns
          if (details.toLowerCase().contains('invalid')) {
            return 'Dados inválidos. Verifique as informações informadas.';
          }
          return details;
        }
        // Se a mensagem contém "Bad Request" ou similar, fornecer mensagem mais amigável
        if (error.message.toLowerCase().contains('bad request') ||
            error.message.toLowerCase().contains('400')) {
          return 'Dados inválidos. Verifique seu e-mail e senha.';
        }
        // Verificar se é erro de campo obrigatório
        if (error.message.toLowerCase().contains('null value') ||
            error.message.toLowerCase().contains('not-null constraint')) {
          return 'Campos obrigatórios não foram preenchidos. Verifique todos os campos do formulário.';
        }
        // Traduzir outras mensagens comuns
        if (error.message.toLowerCase().contains('invalid credentials')) {
          return 'E-mail ou senha incorretos.';
        }
        if (error.message.toLowerCase().contains('user not found')) {
          return 'Usuário não encontrado. Verifique o e-mail informado.';
        }
        if (error.message.toLowerCase().contains('email already registered')) {
          return 'Este e-mail já está cadastrado.';
        }
        return error.message.isNotEmpty
            ? error.message
            : 'Erro ao acessar o banco de dados.';
    }
  }
}
