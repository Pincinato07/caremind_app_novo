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
    if (lowerMessage.contains('network') || lowerMessage.contains('connection')) {
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

