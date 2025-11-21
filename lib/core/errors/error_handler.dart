import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_exception.dart';
import 'failure.dart';

/// Utilitário para converter exceções do Supabase e outras em exceções/Falhas personalizadas
class ErrorHandler {
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
      return AuthenticationException(
        message: error.message,
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
    return UnknownException(
      message: error.toString(),
      originalError: error,
    );
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
      default:
        // Tenta extrair mensagem do detalhe, senão usa a mensagem padrão
        if (error.details != null && error.details.toString().isNotEmpty) {
          return error.details.toString();
        }
        return error.message.isNotEmpty
            ? error.message
            : 'Erro ao acessar o banco de dados.';
    }
  }
}

