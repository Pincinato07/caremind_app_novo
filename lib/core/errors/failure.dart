import 'app_exception.dart';

/// Classe que representa uma falha na aplicação
/// Usada para comunicação de erros de forma mais amigável
abstract class Failure {
  final String message;
  final String? code;
  final AppException? exception;

  const Failure({
    required this.message,
    this.code,
    this.exception,
  });

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => message.hashCode ^ code.hashCode;
}

/// Falha relacionada a problemas de rede
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.exception,
  });
}

/// Falha relacionada a problemas de autenticação
class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    required super.message,
    super.code,
    super.exception,
  });
}

/// Falha relacionada a problemas de banco de dados
class DatabaseFailure extends Failure {
  const DatabaseFailure({
    required super.message,
    super.code,
    super.exception,
  });
}

/// Falha relacionada a problemas de validação
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code,
    super.exception,
  });
}

/// Falha genérica para erros não categorizados
class UnknownFailure extends Failure {
  const UnknownFailure({
    required super.message,
    super.code,
    super.exception,
  });
}

