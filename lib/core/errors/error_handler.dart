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
            return 'Campos obrigatórios não foram preenchidos. Detalhes: $details';
          }
          return details;
        }
        // Se a mensagem contém "Bad Request" ou similar, fornecer mensagem mais amigável
        if (error.message.toLowerCase().contains('bad request') ||
            error.message.toLowerCase().contains('400')) {
          return 'Erro na requisição. Verifique se todos os campos obrigatórios foram preenchidos corretamente.';
        }
        // Verificar se é erro de campo obrigatório
        if (error.message.toLowerCase().contains('null value') ||
            error.message.toLowerCase().contains('not-null constraint')) {
          return 'Campos obrigatórios não foram preenchidos. Verifique todos os campos do formulário.';
        }
        return error.message.isNotEmpty
            ? error.message
            : 'Erro ao acessar o banco de dados.';
    }
  }
}

