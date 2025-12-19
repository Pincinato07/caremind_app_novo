import 'app_exception.dart';

/// Result Type - Either Pattern
///
/// Representa o resultado de uma operação que pode ter sucesso ou falha.
/// Substitui o pattern de `throw Exception()` por um retorno explícito.
///
/// @example
/// ```dart
/// Future<Result<User>> getUser(String id) async {
///   try {
///     final user = await api.fetchUser(id);
///     return Success(user);
///   } catch (e) {
///     return Failure(ErrorHandler.toAppException(e));
///   }
/// }
///
/// // Uso
/// final result = await getUser('123');
/// switch (result) {
///   case Success(:final data):
///     print('User: ${data.name}');
///   case Failure(:final exception):
///     print('Error: ${exception.message}');
/// }
/// ```

sealed class Result<T> {
  const Result();

  /// Executa uma função baseada no tipo de resultado
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failure(:final exception) => failure(exception),
    };
  }

  /// Executa uma função apenas se for sucesso, caso contrário retorna null
  R? whenSuccess<R>(R Function(T data) fn) {
    return switch (this) {
      Success(:final data) => fn(data),
      Failure() => null,
    };
  }

  /// Executa uma função apenas se for falha, caso contrário retorna null
  R? whenFailure<R>(R Function(AppException exception) fn) {
    return switch (this) {
      Success() => null,
      Failure(:final exception) => fn(exception),
    };
  }

  /// Retorna true se for sucesso
  bool get isSuccess => this is Success<T>;

  /// Retorna true se for falha
  bool get isFailure => this is Failure<T>;

  /// Retorna os dados se for sucesso, caso contrário retorna null
  T? get dataOrNull {
    return switch (this) {
      Success(:final data) => data,
      Failure() => null,
    };
  }

  /// Retorna a exceção se for falha, caso contrário retorna null
  AppException? get exceptionOrNull {
    return switch (this) {
      Success() => null,
      Failure(:final exception) => exception,
    };
  }

  /// Transforma o dado de sucesso aplicando uma função
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success(:final data) => Success(transform(data)),
      Failure(:final exception) => Failure(exception),
    };
  }

  /// Transforma o dado de sucesso aplicando uma função que retorna Result
  Result<R> flatMap<R>(Result<R> Function(T data) transform) {
    return switch (this) {
      Success(:final data) => transform(data),
      Failure(:final exception) => Failure(exception),
    };
  }
}

/// Resultado de sucesso
class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Success<T> && other.data == data;
  }

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

/// Resultado de falha
class Failure<T> extends Result<T> {
  final AppException exception;

  const Failure(this.exception);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure<T> && other.exception == exception;
  }

  @override
  int get hashCode => exception.hashCode;

  @override
  String toString() => 'Failure(${exception.message})';
}
