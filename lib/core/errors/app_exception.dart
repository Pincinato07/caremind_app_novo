/// Classe base para exceções personalizadas da aplicação
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Exceção para erros de rede
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exceção para erros de autenticação
class AuthenticationException extends AppException {
  const AuthenticationException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exceção para erros de banco de dados
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exceção para erros de validação
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exceção genérica para erros não categorizados
class UnknownException extends AppException {
  const UnknownException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exceção para erros de rate limiting
class RateLimitException extends AppException {
  final int retryAfter; // segundos até poder tentar novamente
  final DateTime? blockedUntil; // timestamp de quando o bloqueio expira
  final int? minutosRestantes; // minutos restantes de bloqueio
  final int? limit; // limite total de requisições
  final int? remaining; // requisições restantes

  const RateLimitException({
    required super.message,
    super.code,
    this.retryAfter = 60,
    this.blockedUntil,
    this.minutosRestantes,
    this.limit,
    this.remaining,
    super.originalError,
  });

  /// Retorna mensagem formatada com tempo de espera
  String get formattedMessage {
    if (minutosRestantes != null && minutosRestantes! > 0) {
      return '$message\nTente novamente em $minutosRestantes minuto${minutosRestantes! > 1 ? 's' : ''}.';
    }
    if (blockedUntil != null) {
      final now = DateTime.now();
      final diff = blockedUntil!.difference(now);
      if (diff.inMinutes > 0) {
        return '$message\nTente novamente em ${diff.inMinutes} minuto${diff.inMinutes > 1 ? 's' : ''}.';
      }
    }
    return message;
  }
}

/// Exceção específica para erros de Claim Profile
class ClaimProfileException extends AppException {
  final ClaimProfileErrorCode errorCode;
  final int? tentativasRestantes;

  const ClaimProfileException({
    required super.message,
    required this.errorCode,
    super.code,
    this.tentativasRestantes,
    super.originalError,
  });

  /// Retorna true se o erro é relacionado a código inválido
  bool get isInvalidCode => errorCode == ClaimProfileErrorCode.invalidCode;

  /// Retorna true se o erro é relacionado a código expirado
  bool get isExpiredCode => errorCode == ClaimProfileErrorCode.codeExpired;

  /// Retorna true se o perfil já foi reivindicado
  bool get isAlreadyClaimed =>
      errorCode == ClaimProfileErrorCode.alreadyClaimed;

  /// Retorna mensagem formatada com tentativas restantes (se aplicável)
  String get formattedMessage {
    if (tentativasRestantes != null &&
        tentativasRestantes! > 0 &&
        isInvalidCode) {
      return '$message\nTentativas restantes: $tentativasRestantes';
    }
    return message;
  }
}

/// Códigos de erro específicos para Claim Profile
enum ClaimProfileErrorCode {
  invalidCode,
  codeExpired,
  codeNotFound,
  alreadyClaimed,
  invalidAction,
  profileNotVirtual,
  linkExists,
  invalidProfileType,
}

/// Exceção para erros de duplicação/conflito
class ConflictException extends AppException {
  const ConflictException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exceção para erros de timeout
class TimeoutException extends AppException {
  const TimeoutException({
    required super.message,
    super.code,
    super.originalError,
  });
}
